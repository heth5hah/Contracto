-- Quick test to verify return update functionality
-- Run this after creating a return to see if the order was updated

-- 1. Check if columns exist
SELECT 
    'Column Check' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'orders' AND column_name = 'has_return'
        ) THEN '✅ has_return exists'
        ELSE '❌ has_return MISSING'
    END as result
UNION ALL
SELECT 
    'Column Check',
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'orders' AND column_name = 'return_status'
        ) THEN '✅ return_status exists'
        ELSE '❌ return_status MISSING'
    END
UNION ALL
SELECT 
    'Column Check',
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'orders' AND column_name = 'return_requested_at'
        ) THEN '✅ return_requested_at exists'
        ELSE '❌ return_requested_at MISSING'
    END;

-- 2. Check if triggers exist
SELECT 
    'Trigger Check' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers
            WHERE trigger_name = 'trigger_update_order_on_return_create'
        ) THEN '✅ Trigger exists'
        ELSE '❌ Trigger MISSING'
    END as result;

-- 3. Check RLS policy for updates
SELECT 
    'RLS Policy Check' as test,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies
            WHERE tablename = 'orders' 
            AND policyname = 'Users can update their own orders'
        ) THEN '✅ Update policy exists'
        ELSE '❌ Update policy MISSING'
    END as result;

-- 4. Find recent returns and check if orders were updated
SELECT 
    r.id as return_id,
    r.order_id,
    r.return_status as return_status_in_returns,
    o.has_return,
    o.return_status as return_status_in_orders,
    o.return_requested_at,
    o.order_status,
    CASE 
        WHEN o.has_return = true THEN '✅ Order updated'
        ELSE '❌ Order NOT updated'
    END as status
FROM public.returns r
LEFT JOIN public.orders o ON o.id = r.order_id
ORDER BY r.created_at DESC
LIMIT 10;

-- 5. Count mismatches (returns exist but order not marked)
SELECT 
    COUNT(*) as mismatched_count,
    'Returns exist but orders not marked with has_return' as issue
FROM public.returns r
INNER JOIN public.orders o ON o.id = r.order_id
WHERE o.has_return IS NULL OR o.has_return = false;




