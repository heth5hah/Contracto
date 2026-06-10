-- =============================================================================
-- DYNAMIC BILLING REMINDERS — based on admin-set payment_due_days per order
-- Run this in Supabase SQL Editor.
--
-- Problem with old version:
--   Hardcoded checks at 15, 10, 5, 3, 1 days left.
--   If admin gave 8 days → "15 days left" trigger never fires.
--   If admin gave 8 days → "10 days left" fires on day 2 (wrong context).
--
-- New logic — adapts to whatever admin set (payment_due_days):
--   payment_due_days >= 15  → remind every 5 days from start
--   payment_due_days 5–14   → remind every 3 days
--   payment_due_days < 5    → remind every day
--   Always: remind on due day (0) and day before (1)
--   Overdue: remind every 3 days until paid
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_billing_reminders()
RETURNS jsonb AS $$
DECLARE
    v_order       RECORD;
    v_days_left   INT;
    v_due_days    INT;   -- payment_due_days: how many days admin gave
    v_interval    INT;   -- reminder interval in days
    v_message     TEXT;
    v_title       TEXT;
    v_should_fire BOOLEAN;
    v_count       INT := 0;
    v_order_ref   TEXT;
BEGIN
    FOR v_order IN
        SELECT
            id,
            user_id,
            total_amount,
            payment_due_date,
            COALESCE(payment_due_days, 15) AS due_days  -- fallback 15 if not set
        FROM public.orders
        WHERE (payment_method ILIKE '%credit%' OR payment_source = 'credit')
          AND (payment_status IS NULL OR payment_status = 'pending')
          AND order_status NOT IN ('cancelled', 'returned', 'rejected')
          AND payment_due_date IS NOT NULL
    LOOP
        v_days_left    := DATE(v_order.payment_due_date) - CURRENT_DATE;
        v_due_days     := v_order.due_days;
        v_message      := NULL;
        v_title        := 'Payment Reminder';
        v_should_fire  := false;
        v_order_ref    := UPPER(SUBSTRING(REPLACE(v_order.id::text, '-', ''), 1, 6));

        -- ─── OVERDUE ──────────────────────────────────────────────────────────
        IF v_days_left < 0 THEN
            -- Remind every 3 days while overdue
            IF MOD(ABS(v_days_left), 3) = 0 THEN
                v_should_fire := true;
                v_title   := '⚠️ Account Frozen — Overdue Payment';
                v_message := 'URGENT: Your payment of ₹' || v_order.total_amount ||
                             ' for Order #' || v_order_ref ||
                             ' is OVERDUE by ' || ABS(v_days_left) || ' days. ' ||
                             'Your account is frozen until this is cleared.';
            END IF;

        -- ─── DUE TODAY ────────────────────────────────────────────────────────
        ELSIF v_days_left = 0 THEN
            v_should_fire := true;
            v_title   := '🔴 Payment Due TODAY — Order #' || v_order_ref;
            v_message := 'Your payment of ₹' || v_order.total_amount ||
                         ' for Order #' || v_order_ref ||
                         ' is due TODAY. Please transfer immediately to avoid account freeze.';

        -- ─── DUE TOMORROW ─────────────────────────────────────────────────────
        ELSIF v_days_left = 1 THEN
            v_should_fire := true;
            v_title   := '🟠 Final Reminder — Order #' || v_order_ref;
            v_message := 'Last chance: Your payment of ₹' || v_order.total_amount ||
                         ' for Order #' || v_order_ref ||
                         ' is due TOMORROW (' ||
                         TO_CHAR(v_order.payment_due_date, 'DD Mon YYYY') || '). ' ||
                         'Please clear it to avoid account freeze.';

        -- ─── ACTIVE WINDOW — dynamic interval based on days granted ───────────
        ELSE
            -- Choose reminder interval
            IF v_due_days >= 15 THEN
                v_interval := 5;   -- every 5 days if given >= 15 days
            ELSIF v_due_days >= 5 THEN
                v_interval := 3;   -- every 3 days if given 5–14 days
            ELSE
                v_interval := 1;   -- every day if given < 5 days
            END IF;

            -- Fire if today's days_left is a multiple of the interval
            -- AND days_left > 1 (day 1 handled above, day 0 handled above)
            IF v_days_left > 1 AND MOD(v_days_left, v_interval) = 0 THEN
                v_should_fire := true;

                IF v_days_left <= 3 THEN
                    v_title := '🟠 Urgent: ' || v_days_left || ' Day(s) Left — Order #' || v_order_ref;
                ELSE
                    v_title := 'Reminder: ' || v_days_left || ' Days Left — Order #' || v_order_ref;
                END IF;

                v_message :=
                    CASE
                        WHEN v_days_left <= 3 THEN 'Action Required: '
                        ELSE 'Reminder: '
                    END ||
                    'You have ' || v_days_left || ' day(s) left to pay ₹' ||
                    v_order.total_amount || ' for Order #' || v_order_ref || '. ' ||
                    'Payment window granted: ' || v_due_days || ' days. ' ||
                    'Due by: ' || TO_CHAR(v_order.payment_due_date, 'DD Mon YYYY') || '.';
            END IF;
        END IF;

        -- ─── INSERT (deduplicated per order per day) ──────────────────────────
        IF v_should_fire AND v_message IS NOT NULL THEN
            IF NOT EXISTS (
                SELECT 1
                FROM public.notifications
                WHERE user_id     = v_order.user_id
                  AND type        = 'payment'
                  AND reference_id = v_order.id
                  AND DATE(created_at) = CURRENT_DATE
            ) THEN
                INSERT INTO public.notifications (
                    user_id, type, title, message,
                    source, target, reference_id,
                    is_read, status, created_at
                ) VALUES (
                    v_order.user_id, 'payment', v_title, v_message,
                    'system', 'user', v_order.id,
                    false, 'unread', NOW()
                );
                v_count := v_count + 1;
            END IF;
        END IF;

    END LOOP;

    RETURN jsonb_build_object('success', true, 'notifications_sent', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.generate_billing_reminders TO authenticated;

-- =============================================================================
-- TEST: Run manually to see what would fire today (does NOT insert)
-- =============================================================================
SELECT
    o.id,
    o.customer_name,
    o.total_amount,
    o.payment_due_date,
    o.payment_due_days,
    (DATE(o.payment_due_date) - CURRENT_DATE) AS days_left,
    CASE
        WHEN (DATE(o.payment_due_date) - CURRENT_DATE) < 0 THEN 'OVERDUE'
        WHEN (DATE(o.payment_due_date) - CURRENT_DATE) = 0 THEN 'DUE TODAY'
        WHEN (DATE(o.payment_due_date) - CURRENT_DATE) = 1 THEN 'DUE TOMORROW'
        WHEN COALESCE(o.payment_due_days, 15) >= 15
             AND MOD((DATE(o.payment_due_date) - CURRENT_DATE), 5) = 0 THEN 'FIRES (every 5d)'
        WHEN COALESCE(o.payment_due_days, 15) BETWEEN 5 AND 14
             AND MOD((DATE(o.payment_due_date) - CURRENT_DATE), 3) = 0 THEN 'FIRES (every 3d)'
        WHEN COALESCE(o.payment_due_days, 15) < 5 THEN 'FIRES (daily)'
        ELSE 'silent today'
    END AS reminder_status
FROM public.orders o
WHERE (o.payment_method ILIKE '%credit%' OR o.payment_source = 'credit')
  AND (o.payment_status IS NULL OR o.payment_status = 'pending')
  AND o.order_status NOT IN ('cancelled', 'returned', 'rejected')
  AND o.payment_due_date IS NOT NULL
ORDER BY days_left ASC;
