-- DIAGNOSTIC: Check if RLS policies are actually applied
-- Run this to verify the fix was applied

-- 1. Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename IN ('quote_requests', 'quote_request_items');

-- 2. Check current policies on quote_request_items
SELECT 
    policyname,
    permissive,
    roles,
    cmd as command,
    CASE 
        WHEN qual IS NOT NULL THEN 'Has USING clause'
        ELSE 'No USING clause'
    END as using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
        ELSE 'No WITH CHECK clause'
    END as with_check_clause
FROM pg_policies 
WHERE tablename = 'quote_request_items'
ORDER BY policyname;

-- 3. Check if there's a policy that allows INSERT for everyone
SELECT 
    policyname,
    cmd,
    roles,
    with_check
FROM pg_policies 
WHERE tablename = 'quote_request_items'
AND cmd = 'INSERT';

-- 4. Try a test insert (as admin)
-- This will tell us if the table structure is correct
DO $$
DECLARE
    test_quote_id uuid;
BEGIN
    -- Get a recent quote request ID
    SELECT id INTO test_quote_id 
    FROM quote_requests 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF test_quote_id IS NOT NULL THEN
        -- Try to insert a test item
        INSERT INTO quote_request_items (
            quote_request_id,
            product_name,
            quality_option_name,
            quantity,
            unit
        ) VALUES (
            test_quote_id,
            'TEST PRODUCT - DELETE ME',
            'TEST QUALITY',
            999,
            'units'
        );
        
        RAISE NOTICE 'Test insert successful! quote_request_id: %', test_quote_id;
        
        -- Clean up the test
        DELETE FROM quote_request_items 
        WHERE product_name = 'TEST PRODUCT - DELETE ME';
        
        RAISE NOTICE 'Test item cleaned up';
    ELSE
        RAISE NOTICE 'No quote requests found to test with';
    END IF;
END $$;

-- 5. Check the table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'quote_request_items'
ORDER BY ordinal_position;
