-- Test script to see actual quote_request_items data
-- Run this to see what product names and details are stored

SELECT 
    qr.id as quote_request_id,
    qr.product_name as request_summary,
    qr.status,
    qr.created_at,
    qri.id as item_id,
    qri.product_name as item_product_name,
    qri.quality_option_name,
    qri.quantity,
    qri.unit,
    qri.brand_id,
    qri.category,
    qri.notes as item_notes
FROM quote_requests qr
LEFT JOIN quote_request_items qri ON qri.quote_request_id = qr.id
ORDER BY qr.created_at DESC, qri.id
LIMIT 50;

-- Also check if products join is available
SELECT 
    qri.id,
    qri.product_name,
    qri.quality_option_name,
    qri.product_id,
    p.name as product_table_name,
    p.description as product_description
FROM quote_request_items qri
LEFT JOIN products p ON p.id = qri.product_id
ORDER BY qri.created_at DESC
LIMIT 20;
