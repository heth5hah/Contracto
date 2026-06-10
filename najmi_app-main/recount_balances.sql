-- Run this script in your Supabase SQL Editor
-- This script fixes the actual balances based on the credit_usage history.
-- It forces the database to recalculate the Total Outstanding and Available Credit
-- from the actual usage, bypassing the RLS block that prevented the app from doing it.

DO $$
DECLARE
    v_account RECORD;
    v_total_credits NUMERIC;
    v_total_debits NUMERIC;
    v_true_used NUMERIC;
    v_true_available NUMERIC;
BEGIN
    FOR v_account IN 
        SELECT id, credit_limit 
        FROM public.business_credit_accounts 
    LOOP
        -- Calculate total credits and debits from credit_usage
        SELECT 
            COALESCE(SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN transaction_type = 'debit' THEN amount ELSE 0 END), 0)
        INTO v_total_credits, v_total_debits
        FROM public.credit_usage
        WHERE credit_account_id = v_account.id
        AND description NOT LIKE 'Duplicate Correction%'
        AND description NOT LIKE 'Quote Rejected%';

        -- Calculate true used and available
        v_true_used := GREATEST(0, v_total_debits - v_total_credits);
        
        IF v_account.credit_limit = 0 THEN
            -- Wallet mode
            v_true_available := GREATEST(0, v_total_credits - v_total_debits);
        ELSE
            -- Business credit mode
            v_true_available := GREATEST(0, v_account.credit_limit - v_true_used);
        END IF;

        -- Force update the account
        UPDATE public.business_credit_accounts
        SET available_credit = v_true_available,
            used_credit = v_true_used,
            updated_at = NOW()
        WHERE id = v_account.id;

        RAISE NOTICE 'Fixed account %: Available=%, Used=%', v_account.id, v_true_available, v_true_used;
    END LOOP;
END;
$$;
