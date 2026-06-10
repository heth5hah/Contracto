-- =====================================================
-- secure RPC to recount and synchronize credit balances
-- =====================================================
CREATE OR REPLACE FUNCTION public.recount_business_credit_balances(p_account_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit numeric;
  v_is_wallet boolean;
  v_last_balance numeric;
  v_true_used numeric := 0;
  v_true_available numeric := 0;
  v_total_debits numeric := 0;
  v_total_credits numeric := 0;
BEGIN
  -- 1. Fetch the credit account limits
  SELECT credit_limit 
  INTO v_limit
  FROM public.business_credit_accounts
  WHERE id = p_account_id;

  IF v_limit IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Credit account not found');
  END IF;

  v_is_wallet := (v_limit = 0);

  -- 2. Find the last transaction's balance_after in credit_usage
  SELECT balance_after
  INTO v_last_balance
  FROM public.credit_usage
  WHERE credit_account_id = p_account_id
    AND description NOT LIKE 'Duplicate Correction%'
    AND description NOT LIKE 'Quote Rejected%'
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  -- 3. Calculate total debits and credits from credit_usage
  SELECT COALESCE(SUM(ABS(amount)), 0)
  INTO v_total_debits
  FROM public.credit_usage
  WHERE credit_account_id = p_account_id 
    AND transaction_type = 'debit'
    AND description NOT LIKE 'Duplicate Correction%'
    AND description NOT LIKE 'Quote Rejected%';

  SELECT COALESCE(SUM(ABS(amount)), 0)
  INTO v_total_credits
  FROM public.credit_usage
  WHERE credit_account_id = p_account_id 
    AND transaction_type != 'debit'
    AND description NOT LIKE 'Duplicate Correction%'
    AND description NOT LIKE 'Quote Rejected%';

  -- 4. Calculate true balance values
  IF v_is_wallet THEN
    -- Wallet mode: KEEP ORIGINAL SUMMATION LOGIC UNCHANGED
    v_true_available := GREATEST(0, v_total_credits - v_total_debits);
    v_true_used := v_total_debits;
  ELSE
    -- Business credit mode: Use the new last-ledger-entry balance_after logic
    IF v_last_balance IS NOT NULL THEN
      v_true_available := v_last_balance;
      v_true_used := GREATEST(0, v_limit - v_true_available);
    ELSE
      -- Default fallback if no transaction history exists
      v_true_available := v_limit;
      v_true_used := 0;
    END IF;
  END IF;

  -- 5. Update the account record atomically
  UPDATE public.business_credit_accounts
  SET 
    used_credit = v_true_used,
    available_credit = v_true_available,
    updated_at = now()
  WHERE id = p_account_id;

  -- 6. If business credit, update open billing cycle outstanding amount
  IF NOT v_is_wallet THEN
    UPDATE public.billing_cycles
    SET outstanding_amount = v_true_used, updated_at = now()
    WHERE credit_account_id = p_account_id AND status = 'open';
  END IF;

  RETURN jsonb_build_object(
    'success', true, 
    'is_wallet', v_is_wallet,
    'total_debits', v_total_debits,
    'total_credits', v_total_credits,
    'last_balance', v_last_balance,
    'new_used', v_true_used,
    'new_available', v_true_available
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.recount_business_credit_balances(uuid) TO authenticated;

-- Run recount for all existing accounts to immediately synchronize current database state
SELECT public.recount_business_credit_balances(id) FROM public.business_credit_accounts;
