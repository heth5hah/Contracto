-- Quick verification that all fixes were applied

-- Check quote_items RLS policies
SELECT 'quote_items RLS policies:' as check_name;
SELECT policyname, cmd, roles
FROM pg_policies
WHERE tablename = 'quote_items'
ORDER BY policyname;

-- Check quotes RLS policies  
SELECT 'quotes RLS policies:' as check_name;
SELECT policyname, cmd, roles
FROM pg_policies
WHERE tablename = 'quotes'
ORDER BY policyname;

-- Check quote_request_items RLS policies
SELECT 'quote_request_items RLS policies:' as check_name;
SELECT policyname, cmd, roles
FROM pg_policies
WHERE tablename = 'quote_request_items'
ORDER BY policyname;

-- Check if columns exist
SELECT 'quote_items columns:' as check_name;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'quote_items'
ORDER BY column_name;

SELECT 'quotes columns:' as check_name;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'quotes'
ORDER BY column_name;

-- Summary
SELECT '✅ If you see policies listed above, the fix worked!' as result;
SELECT 'Now try saving a quote in the admin panel' as next_step;
