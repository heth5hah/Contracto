-- Run this query in Supabase SQL Editor to check the exact column names in your users table

SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- This will show you all the column names in your users table
-- Look for any column related to PAN - it might be 'pan' or 'pan_number'
