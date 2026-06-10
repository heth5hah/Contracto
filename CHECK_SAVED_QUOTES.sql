-- Check if quotes and quote_items were saved correctly

-- Get the most recent quote request
SELECT 
    qr.id as quote_request_id,
    qr.status,
    qr.product_name,
    qr.created_at,
    COUNT(DISTINCT qri.id) as request_items_count,
    COUNT(DISTINCT q.id) as quotes_count,
    COUNT(DISTINCT qi.id) as quote_items_count
FROM quote_requests qr
LEFT JOIN quote_request_items qri ON qri.quote_request_id = qr.id
LEFT JOIN quotes q ON q.quote_request_id = qr.id
LEFT JOIN quote_items qi ON qi.quote_id = q.id
GROUP BY qr.id, qr.status, qr.product_name, qr.created_at
ORDER BY qr.created_at DESC
LIMIT 5;

-- Get detailed quote information
SELECT 
    'Quote Details:' as info;

SELECT 
    q.id as quote_id,
    q.quote_request_id,
    q.subtotal,
    q.tax_amount,
    q.transport_charges,
    q.total_amount,
    q.status as quote_status,
    qr.status as request_status
FROM quotes q
JOIN quote_requests qr ON qr.id = q.quote_request_id
ORDER BY q.created_at DESC
LIMIT 3;

-- Get quote items with prices
SELECT 
    'Quote Items with Prices:' as info;

SELECT 
    qi.id,
    qi.quote_id,
    qi.quality_option_name as product,
    qi.quantity,
    qi.unit,
    qi.unit_price,
    qi.total_price
FROM quote_items qi
JOIN quotes q ON q.id = qi.quote_id
ORDER BY q.created_at DESC, qi.id
LIMIT 10;

-- Check if status was updated to 'quoted'
SELECT 
    'Quote Requests with Status = quoted:' as info;

SELECT 
    id,
    product_name,
    status,
    total_amount,
    created_at
FROM quote_requests
WHERE status = 'quoted'
ORDER BY created_at DESC
LIMIT 5;
