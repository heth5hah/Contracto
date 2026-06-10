-- CRITICAL: Check ACTUAL database value for D-rex Rubber ring
-- Run this in Supabase SQL Editor RIGHT NOW

SELECT 
  id,
  product_id,
  product_name,
  stock_status,
  stock_quantity,
  updated_at
FROM products
WHERE id = '17455da1-65a0-4cfc-a8fd-cef2fc5f9b06';

-- If stock_status shows 'out_of_stock', run this:
/*
UPDATE products 
SET 
  stock_status = 'in_stock',
  updated_at = NOW()
WHERE id = '17455da1-65a0-4cfc-a8fd-cef2fc5f9b06';

-- Then check again:
SELECT product_name, stock_status FROM products 
WHERE id = '17455da1-65a0-4cfc-a8fd-cef2fc5f9b06';
*/
