-- Function to check open billing cycles and send reminder notifications
-- This should ideally be run daily via pg_cron or an Edge Function.

CREATE OR REPLACE FUNCTION check_and_send_billing_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    cycle RECORD;
    days_left INT;
    user_id UUID;
BEGIN
    FOR cycle IN
        SELECT bc.id, bc.due_date, bc.outstanding_amount, bca.user_id
        FROM billing_cycles bc
        JOIN business_credit_accounts bca ON bca.id = bc.credit_account_id
        WHERE bc.status = 'open' AND bc.due_date IS NOT NULL AND bc.outstanding_amount > 0
    LOOP
        -- Calculate days left until due date
        days_left := (cycle.due_date - CURRENT_DATE);

        -- Send reminders on specific days: 15, 10, 5, 1, and 0
        IF days_left IN (15, 10, 5, 1, 0) THEN
            INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
            VALUES (
                cycle.user_id,
                CASE 
                    WHEN days_left = 0 THEN 'Payment Due Today!'
                    ELSE 'Payment Reminder: ' || days_left || ' days to go'
                END,
                'Your business credit bill of ₹' || cycle.outstanding_amount || ' is due ' || 
                CASE 
                    WHEN days_left = 0 THEN 'today (' || cycle.due_date || '). Please pay immediately to avoid account freeze.'
                    ELSE 'in ' || days_left || ' days on ' || cycle.due_date || '.'
                END,
                'billing',
                false,
                NOW()
            );
        END IF;

        -- If it's overdue, we could also send a "Frozen" notification if it wasn't sent yet
        IF days_left = -1 THEN
            INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
            VALUES (
                cycle.user_id,
                'Account Frozen: Overdue Payment',
                'Your business credit bill of ₹' || cycle.outstanding_amount || ' is overdue. Your purchasing ability is temporarily frozen until the pending amount is cleared.',
                'alert',
                false,
                NOW()
            );
        END IF;
    END LOOP;
END;
$$;

-- Note: To run this automatically every day at midnight, you would use pg_cron (if enabled in Supabase):
-- SELECT cron.schedule('billing-reminders', '0 0 * * *', 'SELECT check_and_send_billing_reminders()');
