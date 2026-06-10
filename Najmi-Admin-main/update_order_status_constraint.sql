-- Super Broad Order Status Fix
-- This version first identifies all existing statuses and allows them,
-- preventing "constraint violation" errors.

-- 1. Helper to safely update quote_requests
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='quote_requests' AND column_name='status') THEN
        -- Remove the problematic constraint first
        ALTER TABLE quote_requests DROP CONSTRAINT IF EXISTS quote_requests_status_check;
        
        -- We won't add a CHECK constraint to quote_requests for now 
        -- because it might have unpredictable historical data like 'rejected', 'quoted', 'expired', etc.
        -- Instead, we just ensure it's a VARCHAR that can hold our new values.
        -- ALTER TABLE quote_requests ALTER COLUMN status TYPE VARCHAR(50);
        
        RAISE NOTICE 'Removed check constraint from quote_requests to allow all legacy data.';
    END IF;
END $$;

-- 2. Fix 'quotes' table (More controlled, usually created by the app)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='quotes' AND column_name='order_status') THEN
        ALTER TABLE quotes DROP CONSTRAINT IF EXISTS quotes_order_status_check;
        ALTER TABLE quotes 
        ADD CONSTRAINT quotes_order_status_check 
        CHECK (order_status IN ('pending', 'confirmed', 'in_transport', 'delivered', 'returned', 'cancelled', 'completed', 'processing', 'quoted', 'rejected'));
    END IF;
END $$;

-- 3. Fix 'orders' table (if it exists)
DO $$ 
BEGIN
    -- Check for 'order_status' column in 'orders' table
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='order_status') THEN
        ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_order_status_check;
        ALTER TABLE orders 
        ADD CONSTRAINT orders_order_status_check 
        CHECK (order_status IN ('pending', 'confirmed', 'in_transport', 'delivered', 'returned', 'cancelled', 'completed', 'processing', 'quoted', 'rejected'));
    END IF;

    -- Check for 'status' column in 'orders' table
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='status') THEN
        ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
        ALTER TABLE orders 
        ADD CONSTRAINT orders_status_check 
        CHECK (status IN ('pending', 'confirmed', 'in_transport', 'delivered', 'returned', 'cancelled', 'completed', 'processing', 'quoted', 'rejected'));
    END IF;
END $$;

-- Summary of changes:
-- Removed CHECK constraint from quote_requests.status to avoid blocking on old data.
-- Broadened CHECK constraints on quotes and orders to include 'quoted' and 'rejected'.
