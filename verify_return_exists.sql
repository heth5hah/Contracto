-- Verify Return Request Exists
-- Run this to check if the return request is in the database

-- 1. Check all returns
SELECT 
    r.id,
    r.order_id,
    r.return_status,
    r.return_reason,
    r.refund_amount,
    r.created_at,
    o.order_status,
    o.customer_name
FROM returns r
LEFT JOIN orders o ON o.id = r.order_id
ORDER BY r.created_at DESC
LIMIT 10;

-- 2. Check return items
SELECT 
    ri.id,
    ri.return_id,
    ri.product_name,
    ri.quantity,
    ri.total_price,
    r.order_id,
    r.return_status
FROM return_items ri
LEFT JOIN returns r ON r.id = ri.return_id
ORDER BY ri.created_at DESC
LIMIT 10;

-- 3. Check specific order (replace with your order ID from mobile app)
-- The order ID from mobile app appears to be: 51B4004E7735
-- But in database it might be a full UUID
SELECT 
    o.id,
    o.order_status,
    o.customer_name,
    COUNT(r.id) as return_count
FROM orders o
LEFT JOIN returns r ON r.order_id = o.id
WHERE o.id::text LIKE '%51B4004E7735%' 
   OR o.id::text LIKE '%51b4004e7735%'
GROUP BY o.id, o.order_status, o.customer_name;

-- 4. Find returns for orders with customer "Prathamesh"
SELECT 
    r.id as return_id,
    r.order_id,
    r.return_status,
    r.refund_amount,
    r.created_at,
    o.customer_name,
    o.order_status
FROM returns r
JOIN orders o ON o.id = r.order_id
WHERE o.customer_name ILIKE '%Prathamesh%'
ORDER BY r.created_at DESC;

