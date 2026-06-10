-- =============================================================================
-- ADD payment_due_days TO orders TABLE
-- Run this in Supabase SQL Editor.
--
-- Purpose: Store the number of days granted by admin for each credit order's
--          payment window. This is set from the Business Billing screen and
--          persisted separately from payment_due_date so we always know
--          "how many days were originally granted" for reminder scheduling.
-- =============================================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_due_days INTEGER DEFAULT NULL;

COMMENT ON COLUMN public.orders.payment_due_days IS
  'Number of days granted by admin for credit payment window. Set from Business Billing screen.';

-- Backfill: derive days for existing orders that already have payment_due_date
UPDATE public.orders
SET payment_due_days = GREATEST(0,
      (DATE(payment_due_date) - DATE(created_at))::integer
    )
WHERE payment_due_date IS NOT NULL
  AND payment_due_days IS NULL;

-- Verify
SELECT id, customer_name, payment_due_date, payment_due_days, payment_source
FROM public.orders
WHERE payment_due_date IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;
