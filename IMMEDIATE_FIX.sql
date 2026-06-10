-- MANUAL FIX: Update D-rex Rubber ring to in_stock RIGHT NOW
-- Copy and paste this into Supabase SQL Editor and run it

UPDATE products 
SET 
  stock_status = 'in_stock',
  updated_at = NOW()
WHERE id = '17455da1-65a0-4cfc-a8fd-cef2fc5f9b06';

-- Verify it worked:
SELECT 
  product_name, 
  stock_status, 
  stock_quantity,
  updated_at 
FROM products 
WHERE id = '17455da1-65a0-4cfc-a8fd-cef2fc5f9b06';

-- Expected result: stock_status should be 'in_stock'
