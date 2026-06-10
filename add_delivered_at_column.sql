-- Add delivered_at column to orders table
-- Run this migration on Supabase SQL Editor

-- 1. Add delivered_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'delivered_at'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN delivered_at timestamp with time zone;
    END IF;
END $$;

-- 2. Update existing delivered orders to have delivered_at set to updated_at (or current time)
-- This allows existing delivered orders to use the return feature
UPDATE public.orders 
SET delivered_at = COALESCE(updated_at, created_at, now())
WHERE order_status = 'delivered' AND delivered_at IS NULL;

-- 3. Verification query
-- SELECT id, order_status, delivered_at, updated_at, created_at FROM orders WHERE order_status = 'delivered';
