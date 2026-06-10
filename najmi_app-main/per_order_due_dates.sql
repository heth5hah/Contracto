-- =========================================================================
-- ENABLE PER-ORDER DUE DATES
-- Run this script in your Supabase SQL Editor
-- =========================================================================

-- 1. Add payment_due_date to orders and quote_requests
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_due_date timestamp with time zone;
ALTER TABLE public.quote_requests ADD COLUMN IF NOT EXISTS payment_due_date timestamp with time zone;

-- 2. Update the Admin Notification RPC to check orders instead of billing_cycles
CREATE OR REPLACE FUNCTION public.generate_billing_reminders()
RETURNS jsonb AS $$
DECLARE
    v_order RECORD;
    v_days_left INT;
    v_message TEXT;
    v_count INT := 0;
BEGIN
    -- Loop through all unpaid credit orders
    FOR v_order IN 
        SELECT id, user_id, total_amount, payment_due_date, customer_name
        FROM public.orders
        WHERE payment_method ILIKE '%credit%'
          AND payment_status = 'pending'
          AND order_status NOT IN ('cancelled', 'returned', 'rejected')
          AND payment_due_date IS NOT NULL
    LOOP
        v_days_left := DATE(v_order.payment_due_date) - CURRENT_DATE;

        -- Determine the message based on days left
        v_message := NULL;

        IF v_days_left = 15 THEN
            v_message := 'You have 15 days left to clear your pending bill of ₹' || v_order.total_amount || ' for Order #' || UPPER(SUBSTRING(v_order.id::text, 1, 6));
        ELSIF v_days_left = 10 THEN
            v_message := 'Reminder: You have 10 days left to clear your pending bill of ₹' || v_order.total_amount || ' for Order #' || UPPER(SUBSTRING(v_order.id::text, 1, 6));
        ELSIF v_days_left = 5 THEN
            v_message := 'Urgent Reminder: 5 days left to clear your pending bill of ₹' || v_order.total_amount || ' for Order #' || UPPER(SUBSTRING(v_order.id::text, 1, 6));
        ELSIF v_days_left = 3 THEN
            v_message := 'Action Required: 3 days left to clear your pending bill of ₹' || v_order.total_amount || ' for Order #' || UPPER(SUBSTRING(v_order.id::text, 1, 6));
        ELSIF v_days_left = 1 THEN
            v_message := 'Final Reminder: Your bill of ₹' || v_order.total_amount || ' for Order #' || UPPER(SUBSTRING(v_order.id::text, 1, 6)) || ' is due tomorrow. Please clear it to avoid account freeze.';
        ELSIF v_days_left = 0 THEN
            v_message := 'Your bill of ₹' || v_order.total_amount || ' for Order #' || UPPER(SUBSTRING(v_order.id::text, 1, 6)) || ' is due TODAY. Please clear it to avoid account freeze.';
        ELSIF v_days_left < 0 AND MOD(ABS(v_days_left), 3) = 0 THEN
            v_message := 'URGENT: Your bill of ₹' || v_order.total_amount || ' for Order #' || UPPER(SUBSTRING(v_order.id::text, 1, 6)) || ' is OVERDUE by ' || ABS(v_days_left) || ' days. Your account is frozen.';
        END IF;

        IF v_message IS NOT NULL THEN
            -- Check if we already sent this exact message today to avoid duplicates
            IF NOT EXISTS (
                SELECT 1 FROM public.notifications 
                WHERE user_id = v_order.user_id 
                  AND type = 'payment'
                  AND title = 'Billing Reminder'
                  AND DATE(created_at) = CURRENT_DATE
                  AND message = v_message
            ) THEN
                -- Insert notification
                INSERT INTO public.notifications (
                    user_id, type, title, message, source, target, status
                ) VALUES (
                    v_order.user_id, 'payment', 'Billing Reminder', v_message, 'system', 'user', 'unread'
                );
                v_count := v_count + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'notifications_sent', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
