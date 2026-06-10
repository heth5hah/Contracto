-- Run this script in your Supabase SQL Editor
-- This will specifically target the order ending in 'D0E0DB4E' and force the deduction.

DO $$
DECLARE
    v_order RECORD;
    v_account_id UUID;
    v_available NUMERIC;
    v_used NUMERIC;
BEGIN
    -- Find the exact order from your screenshot
    FOR v_order IN 
        SELECT id, user_id, total_amount 
        FROM public.orders 
        WHERE id::text ILIKE '%d0e0db4e%'
    LOOP
        -- Find their credit account
        SELECT id, available_credit, used_credit 
        INTO v_account_id, v_available, v_used
        FROM public.business_credit_accounts
        WHERE user_id = v_order.user_id;

        IF FOUND THEN
            -- 1. Insert the history entry if it doesn't exist
            IF NOT EXISTS (
                SELECT 1 FROM public.credit_usage 
                WHERE order_id = v_order.id AND transaction_type = 'debit'
            ) THEN
                INSERT INTO public.credit_usage (
                    credit_account_id, order_id, transaction_type, amount, description, balance_after
                ) VALUES (
                    v_account_id, v_order.id, 'debit', v_order.total_amount, 
                    'Order payment (Forced Fix) - Order #' || substring(v_order.id::text from 1 for 8),
                    GREATEST(0, v_available - v_order.total_amount)
                );
            END IF;

            -- 2. Force the balance update
            UPDATE public.business_credit_accounts
            SET available_credit = GREATEST(0, available_credit - v_order.total_amount),
                used_credit = COALESCE(used_credit, 0) + v_order.total_amount,
                updated_at = NOW()
            WHERE id = v_account_id;

        END IF;
    END LOOP;
END;
$$;
