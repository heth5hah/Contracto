-- Check stock status for D-rex Rubber ring (Product ID: 1303)
SELECT 
  id,
  product_name,
  stock_status,
  stock_quantity,
  updated_at
FROM products
WHERE id = '1303' OR product_name ILIKE '%d-rex rubber ring%';

-- If you want to manually set it to in_stock:
-- UPDATE products 
-- SET stock_status = 'in_stock', updated_at = NOW() 
-- WHERE id = '1303';
