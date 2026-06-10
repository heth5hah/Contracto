-- Diagnostic script to check quote_requests visibility
-- Run this in Supabase SQL Editor to diagnose the issue

-- 1. Check if quote_requests table exists and has data
SELECT 
    'quote_requests' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    MAX(created_at) as latest_request
FROM quote_requests;

-- 2. Check if quote_request_items exist
SELECT 
    'quote_request_items' as table_name,
    COUNT(*) as total_items,
    COUNT(DISTINCT quote_request_id) as unique_requests
FROM quote_request_items;

-- 3. View recent quote requests with items
SELECT 
    qr.id,
    qr.product_name,
    qr.status,
    qr.created_at,
    u.name as user_name,
    u.email as user_email,
    COUNT(qri.id) as item_count
FROM quote_requests qr
LEFT JOIN users u ON u.id = qr.user_id
LEFT JOIN quote_request_items qri ON qri.quote_request_id = qr.id
GROUP BY qr.id, qr.product_name, qr.status, qr.created_at, u.name, u.email
ORDER BY qr.created_at DESC
LIMIT 10;

-- 4. Check RLS policies on quote_requests
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
WHERE tablename = 'quote_requests'
ORDER BY policyname;

-- 5. Check RLS policies on quote_request_items
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
WHERE tablename = 'quote_request_items'
ORDER BY policyname;

-- 6. Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename IN ('quote_requests', 'quote_request_items');
