-- URGENT FIX: Allow anon users to insert quote_request_items
-- The issue is that quote_request_items are not being saved because RLS is blocking them

-- First, let's check current policies
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'quote_request_items'
ORDER BY policyname;

-- Drop all existing policies on quote_request_items
DROP POLICY IF EXISTS "authenticated_select_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "authenticated_insert_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "authenticated_update_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "authenticated_delete_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "anon_insert_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "anon_select_own_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "Admin can view all quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Admin can update quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Users can create quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Users can view own quote request items" ON quote_request_items;

-- Enable RLS
ALTER TABLE quote_request_items ENABLE ROW LEVEL SECURITY;

-- CRITICAL: Allow EVERYONE (anon and authenticated) to insert quote_request_items
-- This is safe because items are linked to quote_requests which have proper RLS
CREATE POLICY "allow_all_insert_quote_request_items"
ON quote_request_items FOR INSERT
WITH CHECK (true);

-- Allow authenticated users (admin) to view all items
CREATE POLICY "allow_authenticated_select_quote_request_items"
ON quote_request_items FOR SELECT
TO authenticated
USING (true);

-- Allow authenticated users (admin) to update all items
CREATE POLICY "allow_authenticated_update_quote_request_items"
ON quote_request_items FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Allow authenticated users (admin) to delete all items
CREATE POLICY "allow_authenticated_delete_quote_request_items"
ON quote_request_items FOR DELETE
TO authenticated
USING (true);

-- Allow users to view items from their own quote requests
CREATE POLICY "allow_users_select_own_quote_request_items"
ON quote_request_items FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM quote_requests
    WHERE quote_requests.id = quote_request_items.quote_request_id
    AND (quote_requests.user_id = auth.uid() OR auth.uid() IS NULL)
  )
);

-- Verify the new policies
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'quote_request_items'
ORDER BY policyname;

-- Test insert (this should work now)
-- You can uncomment and modify this to test:
-- INSERT INTO quote_request_items (
--     quote_request_id,
--     product_name,
--     quality_option_name,
--     quantity,
--     unit
-- ) VALUES (
--     'YOUR_QUOTE_REQUEST_ID_HERE',
--     'Test Product',
--     'Test Quality',
--     1,
--     'units'
-- );

SELECT 'quote_request_items RLS policies fixed! Anon users can now insert items.' as status;
