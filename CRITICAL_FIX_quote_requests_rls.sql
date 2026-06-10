-- COMPREHENSIVE FIX FOR QUOTE REQUESTS VISIBILITY
-- This script ensures both mobile app (anon) and admin panel (authenticated) can access quote_requests

-- Step 1: Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Admin can view all quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Admin can update quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Admin can view all quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Admin can update quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Users can create quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Users can view own quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Users can create quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Users can view own quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Anon can create quote requests" ON quote_requests;
DROP POLICY IF EXISTS "Anon can create quote request items" ON quote_request_items;
DROP POLICY IF EXISTS "Allow all access to quote_requests" ON quote_requests;
DROP POLICY IF EXISTS "Allow all access to quote_request_items" ON quote_request_items;

-- Step 2: Enable RLS on both tables
ALTER TABLE quote_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE quote_request_items ENABLE ROW LEVEL SECURITY;

-- Step 3: Create comprehensive policies for AUTHENTICATED users (Admin Panel)
-- Admin can do everything
CREATE POLICY "authenticated_select_quote_requests"
ON quote_requests FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "authenticated_insert_quote_requests"
ON quote_requests FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "authenticated_update_quote_requests"
ON quote_requests FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "authenticated_delete_quote_requests"
ON quote_requests FOR DELETE
TO authenticated
USING (true);

-- Step 4: Create comprehensive policies for AUTHENTICATED users on quote_request_items
CREATE POLICY "authenticated_select_quote_request_items"
ON quote_request_items FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "authenticated_insert_quote_request_items"
ON quote_request_items FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "authenticated_update_quote_request_items"
ON quote_request_items FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "authenticated_delete_quote_request_items"
ON quote_request_items FOR DELETE
TO authenticated
USING (true);

-- Step 5: Create policies for ANON users (Mobile App) - they can only create
CREATE POLICY "anon_insert_quote_requests"
ON quote_requests FOR INSERT
TO anon
WITH CHECK (true);

CREATE POLICY "anon_insert_quote_request_items"
ON quote_request_items FOR INSERT
TO anon
WITH CHECK (true);

-- Step 6: Allow anon to view their own requests (if they're logged in as authenticated but using anon key)
CREATE POLICY "anon_select_own_quote_requests"
ON quote_requests FOR SELECT
TO anon
USING (auth.uid() = user_id);

CREATE POLICY "anon_select_own_quote_request_items"
ON quote_request_items FOR SELECT
TO anon
USING (
  EXISTS (
    SELECT 1 FROM quote_requests
    WHERE quote_requests.id = quote_request_items.quote_request_id
    AND quote_requests.user_id = auth.uid()
  )
);

-- Step 7: Verify the policies were created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename IN ('quote_requests', 'quote_request_items')
ORDER BY tablename, policyname;

-- Step 8: Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename IN ('quote_requests', 'quote_request_items');

-- Success message
SELECT 'RLS policies updated successfully! Both anon and authenticated users can now access quote_requests.' as status;
