-- Comprehensive diagnostic for real-time issues
-- Run each section separately in Supabase SQL Editor

-- 1. Check if realtime is enabled for products table
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' AND tablename = 'products';
-- Expected: You should see 'products' in results

-- 2. Check current stock_status for D-rex Rubber ring
SELECT 
  id,
  product_name,
  stock_status,
  stock_quantity,
  is_active,
  updated_at
FROM products
WHERE product_name ILIKE '%d-rex%rubber%ring%' OR id = '1303';

-- 3. Check RLS policies on products table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'products';

-- 4. Manually update the product to test (UNCOMMENT to use)
-- UPDATE products 
-- SET 
--   stock_status = 'in_stock',
--   updated_at = NOW()
-- WHERE product_name ILIKE '%d-rex%rubber%ring%';

-- 5. Verify the update worked
-- SELECT product_name, stock_status, updated_at 
-- FROM products 
-- WHERE product_name ILIKE '%d-rex%rubber%ring%';
