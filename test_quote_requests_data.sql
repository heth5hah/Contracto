-- Simple test to verify quote requests are in the database
-- Run this in your Supabase SQL Editor

-- Check how many quote requests exist
SELECT COUNT(*) as total_quote_requests FROM quote_requests;

-- View all quote requests with details
SELECT 
    id,
    user_id,
    product_name,
    category,
    status,
    created_at,
    notes
FROM quote_requests
ORDER BY created_at DESC;

-- Check quote request items
SELECT 
    qr.product_name,
    qr.status,
    qr.created_at,
    qri.quality_option_name,
    qri.quantity,
    qri.unit
FROM quote_requests qr
LEFT JOIN quote_request_items qri ON qr.id = qri.quote_request_id
ORDER BY qr.created_at DESC;

-- Check if users table has the user who created the request
SELECT 
    qr.product_name,
    qr.status,
    u.name as user_name,
    u.email as user_email
FROM quote_requests qr
LEFT JOIN users u ON qr.user_id = u.id
ORDER BY qr.created_at DESC;
