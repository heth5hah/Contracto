-- =========================================================================
-- FIX RPC OVERLOADING
-- Run this script in your Supabase SQL Editor to clean up and unify the deduct_business_credit function
-- =========================================================================

-- 1. Drop both overloaded functions to clear function signature ambiguity
DROP FUNCTION IF EXISTS public.deduct_business_credit(uuid, uuid, numeric, text);
DROP FUNCTION IF EXISTS public.deduct_business_credit(uuid, numeric, text, uuid);

-- 2. Create the unified deduct_business_credit function
CREATE OR REPLACE FUNCTION public.deduct_business_credit(
    p_order_id UUID DEFAULT NULL,
    p_amount NUMERIC DEFAULT 0,
    p_description TEXT DEFAULT '',
    p_quote_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_account_id UUID;
    v_user_id UUID;
    v_status TEXT;
    v_available_credit NUMERIC;
    v_used_credit NUMERIC;
    v_new_available NUMERIC;
    v_new_used NUMERIC;
    v_result JSONB;
BEGIN
    -- Get the current user ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;

    -- Get the credit account
    SELECT id, status, available_credit, used_credit 
    INTO v_account_id, v_status, v_available_credit, v_used_credit
    FROM public.business_credit_accounts
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Business credit account not found');
    END IF;

    IF v_status = 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Your business credit line is awaiting admin approval.');
    END IF;

    IF v_status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Your business credit account is currently ' || v_status || '. Please contact the admin.');
    END IF;

    IF p_amount > v_available_credit THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient business credit available. Available: ₹' || v_available_credit);
    END IF;

    -- Check for frozen account (pending individual orders)
    IF EXISTS (
        SELECT 1 FROM public.orders 
        WHERE user_id = v_user_id 
          AND payment_method ILIKE '%credit%'
          AND payment_status = 'pending'
          AND order_status NOT IN ('cancelled', 'returned', 'rejected')
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Account is temporarily frozen because you have pending payments. Please clear your dues before placing a new order.');
    END IF;

    -- Calculate new balance
    v_new_available := v_available_credit - p_amount;
    v_new_used := COALESCE(v_used_credit, 0.0) + p_amount;

    -- Update the credit account
    UPDATE public.business_credit_accounts 
    SET available_credit = v_new_available,
        used_credit = v_new_used,
        updated_at = NOW()
    WHERE id = v_account_id;

    -- Insert into credit_usage
    IF p_quote_id IS NOT NULL THEN
        INSERT INTO public.credit_usage (
            credit_account_id, quote_request_id, transaction_type, amount, description, balance_after
        ) VALUES (
            v_account_id, p_quote_id, 'debit', p_amount, COALESCE(p_description, 'Quotation payment'), v_new_available
        );
    ELSE
        INSERT INTO public.credit_usage (
            credit_account_id, order_id, transaction_type, amount, description, balance_after
        ) VALUES (
            v_account_id, p_order_id, 'debit', p_amount, COALESCE(p_description, 'Order payment'), v_new_available
        );
    END IF;

    v_result := jsonb_build_object(
        'success', true,
        'new_available', v_new_available,
        'new_used', v_new_used,
        'deducted', p_amount
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.deduct_business_credit(uuid, numeric, text, uuid) TO authenticated;

-- Run recount for all existing accounts to immediately synchronize current database state
SELECT public.recount_business_credit_balances(id) FROM public.business_credit_accounts;
