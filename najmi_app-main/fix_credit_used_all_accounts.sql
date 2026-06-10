-- =============================================================================
-- FIX BUSINESS CREDIT USED_CREDIT ACROSS ALL ACCOUNTS
-- Run this in Supabase SQL Editor.
--
-- Problem: used_credit may include orders paid via Bank Transfer or Online
--          Payment, which should NEVER touch the credit line.
--          Also: used_credit may have exceeded credit_limit historically.
--
-- Fix: Recalculate used_credit for every account based ONLY on orders where
--      payment_source = 'credit' OR payment_method ILIKE '%credit%'
--      AND order is not cancelled/returned/rejected.
-- =============================================================================

-- STEP 1: Preview what is wrong BEFORE fixing (run this first, check output)
SELECT
    u.company_name,
    bca.credit_limit,
    bca.used_credit                                                  AS stored_used_credit,
    bca.available_credit                                             AS stored_available_credit,
    COALESCE(correct.real_used, 0)                                   AS correct_used_credit,
    bca.credit_limit - COALESCE(correct.real_used, 0)               AS correct_available_credit,
    bca.used_credit - COALESCE(correct.real_used, 0)                AS overcharged_by
FROM business_credit_accounts bca
JOIN users u ON u.id = bca.user_id
LEFT JOIN (
    SELECT
        user_id,
        SUM(total_amount) AS real_used
    FROM orders
    WHERE
        -- Only count orders that actually used the credit line
        (payment_source = 'credit' OR payment_method ILIKE '%credit%')
        -- Exclude cancelled / returned / rejected orders
        AND order_status NOT IN ('cancelled', 'returned', 'rejected')
        -- Exclude orders that have been paid back
        AND payment_status != 'paid'
    GROUP BY user_id
) correct ON correct.user_id = bca.user_id
ORDER BY overcharged_by DESC;


-- =============================================================================
-- STEP 2: Apply the fix — recalculate used_credit & available_credit for ALL
-- =============================================================================
WITH real_used AS (
    SELECT
        user_id,
        SUM(total_amount) AS real_used_credit
    FROM orders
    WHERE
        (payment_source = 'credit' OR payment_method ILIKE '%credit%')
        AND order_status NOT IN ('cancelled', 'returned', 'rejected')
        AND payment_status != 'paid'
    GROUP BY user_id
)
UPDATE business_credit_accounts bca
SET
    used_credit      = LEAST(COALESCE(ru.real_used_credit, 0), bca.credit_limit),
    available_credit = bca.credit_limit - LEAST(COALESCE(ru.real_used_credit, 0), bca.credit_limit),
    updated_at       = NOW()
FROM real_used ru
WHERE ru.user_id = bca.user_id;

-- Also zero out accounts that have NO active credit orders at all
UPDATE business_credit_accounts bca
SET
    used_credit      = 0,
    available_credit = bca.credit_limit,
    updated_at       = NOW()
WHERE bca.user_id NOT IN (
    SELECT DISTINCT user_id FROM orders
    WHERE (payment_source = 'credit' OR payment_method ILIKE '%credit%')
      AND order_status NOT IN ('cancelled', 'returned', 'rejected')
      AND payment_status != 'paid'
);


-- =============================================================================
-- STEP 3: Tighten the deduct_business_credit RPC to enforce credit_limit
--         AND exclude bank transfer orders from the freeze check
-- =============================================================================
CREATE OR REPLACE FUNCTION public.deduct_business_credit(
    p_order_id UUID DEFAULT NULL,
    p_amount NUMERIC DEFAULT 0,
    p_description TEXT DEFAULT '',
    p_quote_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_account_id     UUID;
    v_user_id        UUID;
    v_status         TEXT;
    v_credit_limit   NUMERIC;
    v_available_credit NUMERIC;
    v_used_credit    NUMERIC;
    v_new_available  NUMERIC;
    v_new_used       NUMERIC;
    v_result         JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    SELECT id, status, credit_limit, available_credit, used_credit
    INTO v_account_id, v_status, v_credit_limit, v_available_credit, v_used_credit
    FROM public.business_credit_accounts
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Business credit account not found';
    END IF;

    IF v_status = 'pending' THEN
        RAISE EXCEPTION 'Your business credit line is awaiting admin approval.';
    END IF;

    IF v_status != 'active' THEN
        RAISE EXCEPTION 'Your business credit account is currently %. Please contact the admin.', v_status;
    END IF;

    -- Hard cap: cannot exceed credit_limit
    IF (COALESCE(v_used_credit, 0) + p_amount) > v_credit_limit THEN
        RAISE EXCEPTION 'This order exceeds your credit limit of ₹%. Available: ₹%',
            v_credit_limit, v_available_credit;
    END IF;

    IF p_amount > v_available_credit THEN
        RAISE EXCEPTION 'Insufficient business credit. Available: ₹%', v_available_credit;
    END IF;

    -- Only freeze check on CREDIT orders (not bank transfer)
    IF EXISTS (
        SELECT 1 FROM public.orders
        WHERE user_id = v_user_id
          AND (payment_source = 'credit' OR payment_method ILIKE '%credit%')
          AND payment_status != 'paid'
          AND order_status NOT IN ('cancelled', 'returned', 'rejected')
    ) THEN
        RAISE EXCEPTION 'You have unpaid credit orders. Please clear your dues before placing a new order.';
    END IF;

    v_new_available := v_available_credit - p_amount;
    v_new_used      := COALESCE(v_used_credit, 0.0) + p_amount;

    UPDATE public.business_credit_accounts
    SET available_credit = v_new_available,
        used_credit      = v_new_used,
        updated_at       = NOW()
    WHERE id = v_account_id;

    IF p_quote_id IS NOT NULL THEN
        INSERT INTO public.credit_usage (
            credit_account_id, quote_request_id, transaction_type, amount, description, balance_after
        ) VALUES (
            v_account_id, p_quote_id, 'debit', p_amount,
            COALESCE(p_description, 'Quotation payment'), v_new_available
        );
    ELSE
        INSERT INTO public.credit_usage (
            credit_account_id, order_id, transaction_type, amount, description, balance_after
        ) VALUES (
            v_account_id, p_order_id, 'debit', p_amount,
            COALESCE(p_description, 'Order payment'), v_new_available
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'new_available_credit', v_new_available,
        'new_used_credit',      v_new_used
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- STEP 4: Verify all accounts look correct after the fix
-- =============================================================================
SELECT
    u.company_name,
    bca.credit_limit,
    bca.used_credit,
    bca.available_credit,
    bca.status
FROM business_credit_accounts bca
JOIN users u ON u.id = bca.user_id
ORDER BY bca.used_credit DESC;
