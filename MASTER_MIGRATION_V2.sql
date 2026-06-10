-- ============================================================
-- MASTER MIGRATION v2: All 9 Features
-- Run ONCE in Supabase SQL Editor. Fully idempotent.
-- ============================================================

-- === 1. Transaction ID on orders & quote_requests ===
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS transaction_id text;
ALTER TABLE public.quote_requests ADD COLUMN IF NOT EXISTS transaction_id text;

-- === 2. Payment source tracking ===
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_source text DEFAULT 'direct';

-- === 3. Product images in items ===
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS product_image text;
ALTER TABLE public.quote_request_items ADD COLUMN IF NOT EXISTS product_image text;
ALTER TABLE public.quote_items ADD COLUMN IF NOT EXISTS product_image text;

-- === 4. Refund destination on returns ===
DO $$ BEGIN
  ALTER TABLE public.returns ADD COLUMN IF NOT EXISTS refund_destination text DEFAULT 'bank';
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- === 5. Freeze fields on credit accounts ===
ALTER TABLE public.business_credit_accounts ADD COLUMN IF NOT EXISTS is_frozen boolean DEFAULT false;
ALTER TABLE public.business_credit_accounts ADD COLUMN IF NOT EXISTS freeze_reason text;
ALTER TABLE public.business_credit_accounts ADD COLUMN IF NOT EXISTS frozen_at timestamptz;

-- === 6. Audit log table ===
CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT audit_log_pkey PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON public.audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON public.audit_log(entity_type, entity_id);

-- === 7. Indexes for performance ===
CREATE INDEX IF NOT EXISTS idx_orders_txn_id ON public.orders(transaction_id) WHERE transaction_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bca_frozen ON public.business_credit_accounts(is_frozen) WHERE is_frozen = true;

-- === 8. Update notification type constraint ===
DO $$ BEGIN
  ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
  ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
    CHECK (type = ANY (ARRAY['order','quotation','return','refund','payment','system','enquiry','other','billing','credit']));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- === RLS for audit_log ===
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_admin_read" ON public.audit_log;
CREATE POLICY "audit_admin_read" ON public.audit_log FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "audit_user_read" ON public.audit_log;
CREATE POLICY "audit_user_read" ON public.audit_log FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "audit_insert" ON public.audit_log;
CREATE POLICY "audit_insert" ON public.audit_log FOR INSERT WITH CHECK (true);

-- ============================================================
-- CORE FIX: Reliable credit deduction RPC (SECURITY DEFINER)
-- Bypasses RLS to ensure credit ALWAYS gets deducted
-- ============================================================

CREATE OR REPLACE FUNCTION public.deduct_business_credit(
  p_order_id text,
  p_amount numeric,
  p_description text DEFAULT 'Order payment'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_account RECORD;
  v_new_available numeric;
  v_new_used numeric;
BEGIN
  -- Get user_id from auth
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get credit account (must be active)
  SELECT * INTO v_account FROM public.business_credit_accounts
    WHERE user_id = v_user_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active credit account found');
  END IF;

  -- Check frozen
  IF v_account.is_frozen = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is frozen due to overdue payment. Clear your pending dues first.');
  END IF;

  -- Check sufficient credit
  IF p_amount > v_account.available_credit THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Insufficient credit. Available: ₹' || v_account.available_credit::text || ', Required: ₹' || p_amount::text);
  END IF;

  -- Deduct credit
  v_new_available := v_account.available_credit - p_amount;
  v_new_used := v_account.used_credit + p_amount;

  UPDATE public.business_credit_accounts
  SET available_credit = v_new_available,
      used_credit = v_new_used,
      updated_at = now()
  WHERE id = v_account.id;

  -- Record in credit_usage for tracking
  INSERT INTO public.credit_usage (
    credit_account_id, order_id, transaction_type, amount, description, balance_after
  ) VALUES (
    v_account.id, p_order_id::uuid, 'debit', p_amount, p_description, v_new_available
  );

  -- Mark order payment_source as credit
  BEGIN
    UPDATE public.orders SET payment_source = 'credit' WHERE id = p_order_id::uuid;
  EXCEPTION WHEN OTHERS THEN NULL; -- order may not exist yet for quote flows
  END;

  -- Audit log
  INSERT INTO public.audit_log (user_id, action, entity_type, entity_id, details)
  VALUES (v_user_id, 'credit_deducted', 'order', p_order_id,
    jsonb_build_object('amount', p_amount, 'new_available', v_new_available, 'new_used', v_new_used));

  RETURN jsonb_build_object('success', true, 'new_available', v_new_available, 'new_used', v_new_used);
END;
$$;

-- ============================================================
-- CORE FIX: Reliable credit restoration on return (business)
-- Only restores if order was originally paid via credit
-- ============================================================

CREATE OR REPLACE FUNCTION public.restore_credit_for_return(
  p_order_id text,
  p_return_id text,
  p_refund_amount numeric,
  p_description text DEFAULT 'Return refund'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_account RECORD;
  v_new_available numeric;
  v_new_used numeric;
BEGIN
  -- Get order
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  -- Get credit account for the order's user
  SELECT * INTO v_account FROM public.business_credit_accounts
    WHERE user_id = v_order.user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No credit account for this user');
  END IF;

  -- Check: was this order paid via credit?
  IF COALESCE(v_order.payment_source, 'direct') != 'credit' THEN
    -- Order was bank-paid → refund goes to bank, credit line stays untouched
    UPDATE public.returns SET refund_destination = 'bank' WHERE id = p_return_id::uuid;
    
    INSERT INTO public.audit_log (user_id, action, entity_type, entity_id, details)
    VALUES (v_order.user_id, 'bank_refund_flagged', 'return', p_return_id,
      jsonb_build_object('amount', p_refund_amount, 'reason', 'Order was not credit-paid'));

    RETURN jsonb_build_object('success', true, 'refund_destination', 'bank',
      'message', 'Order was bank-paid. Refund to bank. Credit line unchanged.');
  END IF;

  -- Order WAS credit-paid → restore to credit line
  v_new_available := v_account.available_credit + p_refund_amount;
  v_new_used := GREATEST(v_account.used_credit - p_refund_amount, 0);

  UPDATE public.business_credit_accounts
  SET available_credit = v_new_available,
      used_credit = v_new_used,
      updated_at = now()
  WHERE id = v_account.id;

  -- Record credit restoration
  INSERT INTO public.credit_usage (
    credit_account_id, order_id, transaction_type, amount, description, balance_after
  ) VALUES (
    v_account.id, p_order_id::uuid, 'credit', p_refund_amount, p_description, v_new_available
  );

  -- Mark return destination as credit
  UPDATE public.returns SET refund_destination = 'credit' WHERE id = p_return_id::uuid;

  -- Audit log
  INSERT INTO public.audit_log (user_id, action, entity_type, entity_id, details)
  VALUES (v_order.user_id, 'credit_restored', 'return', p_return_id,
    jsonb_build_object('amount', p_refund_amount, 'new_available', v_new_available, 'new_used', v_new_used));

  RETURN jsonb_build_object('success', true, 'refund_destination', 'credit',
    'new_available', v_new_available, 'new_used', v_new_used);
END;
$$;

-- ============================================================
-- Individual wallet refund (WITHOUT GST)
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_individual_refund(
  p_order_id text,
  p_return_id text,
  p_items_subtotal numeric,
  p_gst_amount numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_account RECORD;
  v_refund_amount numeric;
  v_new_available numeric;
  v_account_id uuid;
BEGIN
  -- Refund = subtotal only (WITHOUT GST)
  v_refund_amount := p_items_subtotal;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  -- Get or create wallet (business_credit_accounts with credit_limit=0)
  SELECT * INTO v_account FROM public.business_credit_accounts
    WHERE user_id = v_order.user_id;

  IF NOT FOUND THEN
    -- Create wallet for individual user
    INSERT INTO public.business_credit_accounts (
      user_id, credit_limit, available_credit, used_credit, status, kyc_status
    ) VALUES (
      v_order.user_id, 0, 0, 0, 'active', 'approved'
    ) RETURNING * INTO v_account;
  END IF;

  v_account_id := v_account.id;
  v_new_available := v_account.available_credit + v_refund_amount;

  -- Credit the wallet
  UPDATE public.business_credit_accounts
  SET available_credit = v_new_available, updated_at = now()
  WHERE id = v_account_id;

  -- Record transaction
  INSERT INTO public.credit_usage (
    credit_account_id, order_id, transaction_type, amount, description, balance_after
  ) VALUES (
    v_account_id, p_order_id::uuid, 'credit', v_refund_amount,
    'Return refund (excl. GST ₹' || p_gst_amount::text || ')', v_new_available
  );

  -- Update return record
  UPDATE public.returns
  SET refund_amount_final = v_refund_amount,
      refund_destination = 'credit',
      updated_at = now()
  WHERE id = p_return_id::uuid;

  -- Audit log
  INSERT INTO public.audit_log (user_id, action, entity_type, entity_id, details)
  VALUES (v_order.user_id, 'wallet_refund', 'return', p_return_id,
    jsonb_build_object('subtotal', p_items_subtotal, 'gst_excluded', p_gst_amount,
      'refunded', v_refund_amount, 'new_balance', v_new_available));

  -- Notify user
  INSERT INTO public.notifications (user_id, title, message, type, source, target, reference_id, is_read)
  VALUES (v_order.user_id, 'Refund Credited to Wallet',
    '₹' || v_refund_amount::text || ' has been added to your wallet (GST of ₹' || p_gst_amount::text || ' excluded).',
    'refund', 'system', 'user', p_return_id::uuid, false);

  RETURN jsonb_build_object('success', true, 'refund_amount', v_refund_amount,
    'gst_excluded', p_gst_amount, 'new_wallet_balance', v_new_available);
END;
$$;

-- ============================================================
-- Auto-freeze overdue accounts (call via CRON daily)
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_and_freeze_overdue_accounts()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE rec RECORD;
BEGIN
  FOR rec IN
    SELECT DISTINCT bca.id AS account_id, bca.user_id
    FROM public.business_credit_accounts bca
    JOIN public.orders o ON o.user_id = bca.user_id
    WHERE bca.is_frozen = false AND bca.status = 'active'
      AND o.payment_due_date IS NOT NULL AND o.payment_due_date < CURRENT_DATE
      AND o.payment_status = 'pending'
      AND o.order_status NOT IN ('cancelled','returned','rejected')
  LOOP
    UPDATE public.business_credit_accounts
    SET is_frozen = true, freeze_reason = 'Overdue payment', frozen_at = now(), updated_at = now()
    WHERE id = rec.account_id;

    INSERT INTO public.notifications (user_id, title, message, type, source, target, is_read)
    VALUES (rec.user_id, 'Account Frozen - Payment Overdue',
      'Your business account has been frozen due to overdue payment. Please clear your pending dues to continue purchasing.',
      'payment', 'system', 'user', false);

    INSERT INTO public.audit_log (user_id, action, entity_type, entity_id, details)
    VALUES (rec.user_id, 'account_frozen', 'business_credit_account', rec.account_id::text,
      jsonb_build_object('reason', 'overdue_payment', 'auto', true));
  END LOOP;
END;
$$;

-- ============================================================
-- Payment reminder notifications (call via CRON daily)
-- ============================================================

CREATE OR REPLACE FUNCTION public.send_payment_reminders()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE rec RECORD; days_left integer;
BEGIN
  FOR rec IN
    SELECT o.id AS order_id, o.user_id, o.payment_due_date, o.total_amount
    FROM public.orders o
    WHERE o.payment_due_date IS NOT NULL AND o.payment_status = 'pending'
      AND o.order_status NOT IN ('cancelled','returned','rejected')
      AND o.payment_due_date >= CURRENT_DATE
  LOOP
    days_left := (rec.payment_due_date - CURRENT_DATE);
    IF days_left IN (15,10,5,3,1) THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.notifications 
        WHERE user_id = rec.user_id AND reference_id = rec.order_id 
          AND created_at::date = CURRENT_DATE AND title LIKE '%Payment Reminder%'
      ) THEN
        INSERT INTO public.notifications (user_id, title, message, type, source, target, reference_id, is_read)
        VALUES (rec.user_id, 'Payment Reminder - ' || days_left || ' Days Left',
          days_left || ' day(s) remaining to pay ₹' || rec.total_amount || '. Account will freeze after due date.',
          'payment', 'system', 'user', rec.order_id, false);
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- ============================================================
-- Account deletion check
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_delete_account(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_used numeric;
  v_pending int;
  v_returns int;
  v_reasons jsonb := '[]'::jsonb;
BEGIN
  SELECT COALESCE(used_credit,0) INTO v_used 
  FROM public.business_credit_accounts WHERE user_id = p_user_id;
  IF v_used > 0 THEN 
    v_reasons := v_reasons || jsonb_build_array('Pending credit dues: ₹' || v_used::text); 
  END IF;

  SELECT COUNT(*) INTO v_pending FROM public.orders 
  WHERE user_id = p_user_id AND payment_status = 'pending' 
    AND order_status NOT IN ('cancelled','rejected');
  IF v_pending > 0 THEN 
    v_reasons := v_reasons || jsonb_build_array(v_pending || ' unpaid order(s)'); 
  END IF;

  SELECT COUNT(*) INTO v_returns FROM public.returns 
  WHERE user_id = p_user_id 
    AND return_status NOT IN ('completed','refund_completed','rejected','cancelled');
  IF v_returns > 0 THEN 
    v_reasons := v_reasons || jsonb_build_array(v_returns || ' pending return(s)'); 
  END IF;

  RETURN jsonb_build_object('can_delete', jsonb_array_length(v_reasons) = 0, 'reasons', v_reasons);
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================
GRANT EXECUTE ON FUNCTION public.deduct_business_credit(text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_credit_for_return(text, text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_individual_refund(text, text, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_freeze_overdue_accounts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_payment_reminders() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_delete_account(uuid) TO authenticated;

-- ============================================================
-- DONE. 
-- NEXT: Set up pg_cron in Supabase Dashboard → SQL Editor:
--
-- SELECT cron.schedule(
--   'freeze-overdue-accounts',
--   '30 18 * * *',  -- 18:30 UTC = midnight IST
--   $$SELECT public.check_and_freeze_overdue_accounts()$$
-- );
-- SELECT cron.schedule(
--   'send-payment-reminders', 
--   '0 3 * * *',  -- 3:00 UTC = 8:30 AM IST
--   $$SELECT public.send_payment_reminders()$$
-- );
-- ============================================================
