-- =========================================================================
-- BILLING REMINDERS & NOTIFICATIONS FUNCTION
-- Run this script in your Supabase SQL Editor
-- =========================================================================

-- Create a function to generate billing reminders
CREATE OR REPLACE FUNCTION public.generate_billing_reminders()
RETURNS jsonb AS $$
DECLARE
    v_cycle RECORD;
    v_days_left INT;
    v_message TEXT;
    v_user_id UUID;
    v_count INT := 0;
BEGIN
    -- Loop through all active credit orders with pending payments
    FOR v_cycle IN 
        SELECT id as order_id, user_id, payment_due_date as due_date, total_amount as outstanding_amount
        FROM public.orders
        WHERE payment_method ILIKE '%credit%'
          AND payment_status = 'pending'
          AND order_status NOT IN ('cancelled', 'returned', 'rejected')
          AND payment_due_date IS NOT NULL
    LOOP
        v_user_id := v_cycle.user_id;
        v_days_left := v_cycle.due_date::DATE - CURRENT_DATE;

        -- Determine the message based on days left
        v_message := NULL;

        IF v_days_left = 15 THEN
            v_message := 'You have 15 days left to clear your pending bill of ₹' || v_cycle.outstanding_amount || ' for Order #' || UPPER(SUBSTRING(v_cycle.order_id::text, 1, 8));
        ELSIF v_days_left = 10 THEN
            v_message := 'Reminder: You have 10 days left to clear your pending bill of ₹' || v_cycle.outstanding_amount || ' for Order #' || UPPER(SUBSTRING(v_cycle.order_id::text, 1, 8));
        ELSIF v_days_left = 5 THEN
            v_message := 'Urgent Reminder: 5 days left to clear your pending bill of ₹' || v_cycle.outstanding_amount || ' for Order #' || UPPER(SUBSTRING(v_cycle.order_id::text, 1, 8));
        ELSIF v_days_left = 3 THEN
            v_message := 'Action Required: 3 days left to clear your pending bill of ₹' || v_cycle.outstanding_amount || ' for Order #' || UPPER(SUBSTRING(v_cycle.order_id::text, 1, 8));
        ELSIF v_days_left = 1 THEN
            v_message := 'Final Reminder: Your bill of ₹' || v_cycle.outstanding_amount || ' for Order #' || UPPER(SUBSTRING(v_cycle.order_id::text, 1, 8)) || ' is due tomorrow. Please clear it to avoid account freeze.';
        ELSIF v_days_left = 0 THEN
            v_message := 'Your bill of ₹' || v_cycle.outstanding_amount || ' for Order #' || UPPER(SUBSTRING(v_cycle.order_id::text, 1, 8)) || ' is due TODAY. Please clear it to avoid account freeze.';
        ELSIF v_days_left < 0 AND MOD(ABS(v_days_left), 3) = 0 THEN
            -- Send overdue reminder every 3 days
            v_message := 'URGENT: Your bill of ₹' || v_cycle.outstanding_amount || ' for Order #' || UPPER(SUBSTRING(v_cycle.order_id::text, 1, 8)) || ' is OVERDUE by ' || ABS(v_days_left) || ' days. Your account is frozen.';
        END IF;

        IF v_message IS NOT NULL THEN
            -- Check if we already sent this exact message today to avoid duplicates
            IF NOT EXISTS (
                SELECT 1 FROM public.notifications 
                WHERE user_id = v_user_id 
                  AND type = 'payment'
                  AND message = v_message
                  AND DATE(created_at) = CURRENT_DATE
            ) THEN
                -- Insert notification
                INSERT INTO public.notifications (
                    user_id, type, title, message, source, target, status
                ) VALUES (
                    v_user_id, 'payment', 'Billing Reminder', v_message, 'system', 'user', 'unread'
                );
                v_count := v_count + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'notifications_sent', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.generate_billing_reminders TO authenticated;
