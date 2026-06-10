-- =====================================================
-- STEP 1: Drop any old version of the function
-- =====================================================
DROP FUNCTION IF EXISTS public.deduct_business_credit(uuid, uuid, numeric, text);

-- =====================================================
-- STEP 2: Create the RPC function
-- =====================================================
CREATE OR REPLACE FUNCTION public.deduct_business_credit(
  p_order_id uuid DEFAULT NULL,
  p_quote_id uuid DEFAULT NULL,
  p_amount numeric DEFAULT 0,
  p_description text DEFAULT 'Order payment'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_email text;
  v_user_id uuid;
  v_account_id uuid;
  v_available numeric;
  v_used numeric;
  v_new_available numeric;
  v_new_used numeric;
BEGIN
  -- Get email from auth
  SELECT email INTO v_auth_email FROM auth.users WHERE id = auth.uid();
  IF v_auth_email IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Find user in public.users
  SELECT id INTO v_user_id FROM public.users WHERE email = v_auth_email;
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found for email: ' || v_auth_email);
  END IF;

  -- Get and lock credit account
  SELECT id, available_credit, used_credit
  INTO v_account_id, v_available, v_used
  FROM public.business_credit_accounts
  WHERE user_id = v_user_id AND status = 'active'
  FOR UPDATE;

  IF v_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active credit account found');
  END IF;

  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient credit');
  END IF;

  -- Deduct
  v_new_available := v_available - p_amount;
  v_new_used := v_used + p_amount;

  UPDATE public.business_credit_accounts
  SET available_credit = v_new_available, used_credit = v_new_used, updated_at = now()
  WHERE id = v_account_id;

  -- Record transaction
  INSERT INTO public.credit_usage (credit_account_id, order_id, quote_request_id, transaction_type, amount, description, balance_after)
  VALUES (v_account_id, p_order_id, p_quote_id, 'debit', p_amount, p_description, v_new_available);

  RETURN jsonb_build_object('success', true, 'new_available', v_new_available, 'new_used', v_new_used, 'deducted', p_amount);
END;
$$;

-- =====================================================
-- STEP 3: Grant permission
-- =====================================================
GRANT EXECUTE ON FUNCTION public.deduct_business_credit(uuid, uuid, numeric, text) TO authenticated;

-- =====================================================
-- STEP 4: Allow users to UPDATE their own credit account (fallback)
-- =====================================================
ALTER TABLE public.business_credit_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own credit account" ON public.business_credit_accounts;
CREATE POLICY "Users can read own credit account" ON public.business_credit_accounts
  FOR SELECT USING (
    user_id IN (SELECT id FROM public.users WHERE email = (SELECT email FROM auth.users WHERE id = auth.uid()))
  );

DROP POLICY IF EXISTS "Users can update own credit account" ON public.business_credit_accounts;
CREATE POLICY "Users can update own credit account" ON public.business_credit_accounts
  FOR UPDATE USING (
    user_id IN (SELECT id FROM public.users WHERE email = (SELECT email FROM auth.users WHERE id = auth.uid()))
  );

-- =====================================================
-- STEP 5: Allow users to INSERT their own credit_usage
-- =====================================================
ALTER TABLE public.credit_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own credit usage" ON public.credit_usage;
CREATE POLICY "Users can read own credit usage" ON public.credit_usage
  FOR SELECT USING (
    credit_account_id IN (
      SELECT id FROM public.business_credit_accounts
      WHERE user_id IN (SELECT id FROM public.users WHERE email = (SELECT email FROM auth.users WHERE id = auth.uid()))
    )
  );

DROP POLICY IF EXISTS "Users can insert own credit usage" ON public.credit_usage;
CREATE POLICY "Users can insert own credit usage" ON public.credit_usage
  FOR INSERT WITH CHECK (
    credit_account_id IN (
      SELECT id FROM public.business_credit_accounts
      WHERE user_id IN (SELECT id FROM public.users WHERE email = (SELECT email FROM auth.users WHERE id = auth.uid()))
    )
  );

-- =====================================================
-- STEP 6: Verify it was created
-- =====================================================
SELECT 'SUCCESS: RPC + RLS policies created!' AS result;
