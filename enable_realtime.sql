-- Enable Realtime for products table in Supabase
-- Run this in your Supabase SQL Editor

-- 1. Enable realtime for the products table
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- 2. Verify realtime is enabled (optional check)
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';

-- If you see 'products' in the results, realtime is enabled!

-- 3. Grant necessary permissions for realtime
GRANT SELECT ON products TO anon;
GRANT SELECT ON products TO authenticated;

-- 4. Test by running this update manually:
-- UPDATE products SET stock_status = 'in_stock' WHERE product_name ILIKE '%p trap%';
