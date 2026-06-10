-- Fix existing returns and verify database setup
-- Run this in Supabase SQL Editor to:
-- 1. Add missing columns if they don't exist
-- 2. Update existing orders that have returns
-- 3. Verify the setup

-- ====================================================
-- STEP 1: Add columns if they don't exist
-- ====================================================
DO $$
BEGIN
    -- Add has_return column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'has_return'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN has_return boolean DEFAULT false;
        RAISE NOTICE 'Added has_return column';
    ELSE
        RAISE NOTICE 'has_return column already exists';
    END IF;

    -- Add return_status column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'return_status'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN return_status text;
        RAISE NOTICE 'Added return_status column';
    ELSE
        RAISE NOTICE 'return_status column already exists';
    END IF;

    -- Add return_requested_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'return_requested_at'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN return_requested_at timestamp with time zone;
        RAISE NOTICE 'Added return_requested_at column';
    ELSE
        RAISE NOTICE 'return_requested_at column already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Create indexes for performance
-- ====================================================
CREATE INDEX IF NOT EXISTS idx_orders_has_return ON public.orders(has_return) WHERE has_return = true;
CREATE INDEX IF NOT EXISTS idx_orders_return_status ON public.orders(return_status) WHERE return_status IS NOT NULL;

-- ====================================================
-- STEP 3: Update existing orders that have returns
-- ====================================================
UPDATE public.orders o
SET 
    has_return = true,
    return_status = CASE 
        WHEN EXISTS (
            SELECT 1 FROM public.returns r 
            WHERE r.order_id = o.id 
            AND r.return_status = 'pending'
        ) THEN 'Pending Review'
        WHEN EXISTS (
            SELECT 1 FROM public.returns r 
            WHERE r.order_id = o.id 
            AND r.return_status = 'approved'
        ) THEN 'Approved'
        WHEN EXISTS (
            SELECT 1 FROM public.returns r 
            WHERE r.order_id = o.id 
            AND r.return_status = 'rejected'
        ) THEN 'Rejected'
        WHEN EXISTS (
            SELECT 1 FROM public.returns r 
            WHERE r.order_id = o.id 
            AND r.return_status = 'completed'
        ) THEN 'Completed'
        ELSE 'Pending Review'
    END,
    return_requested_at = (
        SELECT MIN(created_at) 
        FROM public.returns r 
        WHERE r.order_id = o.id
    ),
    updated_at = now()
WHERE EXISTS (
    SELECT 1 FROM public.returns r WHERE r.order_id = o.id
);

-- ====================================================
-- STEP 4: Create/Update trigger function
-- ====================================================
CREATE OR REPLACE FUNCTION update_order_on_return_create()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the order when a return is created
    UPDATE public.orders
    SET 
        has_return = true,
        return_status = CASE 
            WHEN NEW.return_status = 'pending' THEN 'Pending Review'
            WHEN NEW.return_status = 'approved' THEN 'Approved'
            WHEN NEW.return_status = 'rejected' THEN 'Rejected'
            WHEN NEW.return_status = 'completed' THEN 'Completed'
            ELSE 'Pending Review'
        END,
        return_requested_at = COALESCE(
            (SELECT MIN(created_at) FROM public.returns WHERE order_id = NEW.order_id),
            NEW.created_at
        ),
        updated_at = now()
    WHERE id = NEW.order_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ====================================================
-- STEP 5: Create/Update trigger
-- ====================================================
DROP TRIGGER IF EXISTS trigger_update_order_on_return_create ON public.returns;
CREATE TRIGGER trigger_update_order_on_return_create
    AFTER INSERT ON public.returns
    FOR EACH ROW
    EXECUTE FUNCTION update_order_on_return_create();

-- ====================================================
-- STEP 6: Create/Update trigger for status changes
-- ====================================================
CREATE OR REPLACE FUNCTION update_order_on_return_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the order when return status changes
    UPDATE public.orders
    SET 
        return_status = CASE 
            WHEN NEW.return_status = 'pending' THEN 'Pending Review'
            WHEN NEW.return_status = 'approved' THEN 'Approved'
            WHEN NEW.return_status = 'rejected' THEN 'Rejected'
            WHEN NEW.return_status = 'completed' THEN 'Completed'
            WHEN NEW.return_status = 'cancelled' THEN NULL
            ELSE return_status
        END,
        updated_at = now()
    WHERE id = NEW.order_id;
    
    -- If return is cancelled, check if there are other pending returns
    IF NEW.return_status = 'cancelled' THEN
        -- Check if there are other non-cancelled returns for this order
        IF NOT EXISTS (
            SELECT 1 FROM public.returns 
            WHERE order_id = NEW.order_id 
            AND return_status != 'cancelled'
        ) THEN
            -- No other returns, clear the return flags
            UPDATE public.orders
            SET 
                has_return = false,
                return_status = NULL,
                return_requested_at = NULL,
                updated_at = now()
            WHERE id = NEW.order_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_order_on_return_status_change ON public.returns;
CREATE TRIGGER trigger_update_order_on_return_status_change
    AFTER UPDATE ON public.returns
    FOR EACH ROW
    WHEN (OLD.return_status IS DISTINCT FROM NEW.return_status)
    EXECUTE FUNCTION update_order_on_return_status_change();

-- ====================================================
-- STEP 7: Ensure RLS allows users to update their orders
-- ====================================================
-- Check if update policy exists, if not create it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'orders' 
        AND policyname = 'Users can update their own orders'
    ) THEN
        CREATE POLICY "Users can update their own orders" ON public.orders
            FOR UPDATE 
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
        RAISE NOTICE 'Created RLS policy: Users can update their own orders';
    ELSE
        RAISE NOTICE 'RLS policy already exists: Users can update their own orders';
    END IF;
END $$;

-- ====================================================
-- STEP 8: Verification Queries
-- ====================================================
-- Check columns
SELECT 
    column_name, 
    data_type, 
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND column_name IN ('has_return', 'return_status', 'return_requested_at')
ORDER BY column_name;

-- Check triggers
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'returns'
ORDER BY trigger_name;

-- Check RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'orders'
ORDER BY policyname;

-- Count orders with returns
SELECT 
    COUNT(*) as total_orders_with_returns,
    COUNT(CASE WHEN has_return = true THEN 1 END) as orders_marked_has_return,
    COUNT(CASE WHEN return_status IS NOT NULL THEN 1 END) as orders_with_return_status
FROM public.orders o
WHERE EXISTS (
    SELECT 1 FROM public.returns r WHERE r.order_id = o.id
);

-- Show sample orders with returns
SELECT 
    o.id,
    o.order_status,
    o.has_return,
    o.return_status,
    o.return_requested_at,
    COUNT(r.id) as return_count
FROM public.orders o
LEFT JOIN public.returns r ON r.order_id = o.id
WHERE EXISTS (SELECT 1 FROM public.returns WHERE order_id = o.id)
GROUP BY o.id, o.order_status, o.has_return, o.return_status, o.return_requested_at
ORDER BY o.return_requested_at DESC NULLS LAST
LIMIT 10;




