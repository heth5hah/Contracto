-- Check if orders exist in the database
SELECT COUNT(*) as total_orders FROM orders;

-- View all orders
SELECT * FROM orders ORDER BY created_at DESC LIMIT 10;

-- Check RLS policies on orders table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'orders';
