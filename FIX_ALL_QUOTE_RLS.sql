-- COMPLETE RLS FIX for all quote-related tables
-- This allows admin panel to insert/update quotes and quote_items

-- ============================================
-- FIX quote_items RLS policies
-- ============================================

-- Drop all existing policies on quote_items
DROP POLICY IF EXISTS "authenticated_select_quote_items" ON quote_items;
DROP POLICY IF EXISTS "authenticated_insert_quote_items" ON quote_items;
DROP POLICY IF EXISTS "authenticated_update_quote_items" ON quote_items;
DROP POLICY IF EXISTS "authenticated_delete_quote_items" ON quote_items;
DROP POLICY IF EXISTS "Admin can view all quote items" ON quote_items;
DROP POLICY IF EXISTS "Admin can insert quote items" ON quote_items;
DROP POLICY IF EXISTS "Admin can update quote items" ON quote_items;
DROP POLICY IF EXISTS "Admin can delete quote items" ON quote_items;
DROP POLICY IF EXISTS "Users can view own quote items" ON quote_items;

-- Enable RLS
ALTER TABLE quote_items ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users (admin) to do everything
CREATE POLICY "allow_authenticated_select_quote_items"
ON quote_items FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "allow_authenticated_insert_quote_items"
ON quote_items FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "allow_authenticated_update_quote_items"
ON quote_items FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "allow_authenticated_delete_quote_items"
ON quote_items FOR DELETE
TO authenticated
USING (true);

-- Allow users to view quote items for their own quotes
CREATE POLICY "allow_users_select_own_quote_items"
ON quote_items FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM quotes
    JOIN quote_requests ON quotes.quote_request_id = quote_requests.id
    WHERE quotes.id = quote_items.quote_id
    AND (quote_requests.user_id = auth.uid() OR auth.uid() IS NULL)
  )
);

-- ============================================
-- FIX quotes RLS policies
-- ============================================

-- Drop all existing policies on quotes
DROP POLICY IF EXISTS "authenticated_select_quotes" ON quotes;
DROP POLICY IF EXISTS "authenticated_insert_quotes" ON quotes;
DROP POLICY IF EXISTS "authenticated_update_quotes" ON quotes;
DROP POLICY IF EXISTS "authenticated_delete_quotes" ON quotes;
DROP POLICY IF EXISTS "Admin can view all quotes" ON quotes;
DROP POLICY IF EXISTS "Admin can insert quotes" ON quotes;
DROP POLICY IF EXISTS "Admin can update quotes" ON quotes;
DROP POLICY IF EXISTS "Admin can delete quotes" ON quotes;
DROP POLICY IF EXISTS "Users can view own quotes" ON quotes;

-- Enable RLS
ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users (admin) to do everything
CREATE POLICY "allow_authenticated_select_quotes"
ON quotes FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "allow_authenticated_insert_quotes"
ON quotes FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "allow_authenticated_update_quotes"
ON quotes FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "allow_authenticated_delete_quotes"
ON quotes FOR DELETE
TO authenticated
USING (true);

-- Allow users to view their own quotes
CREATE POLICY "allow_users_select_own_quotes"
ON quotes FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM quote_requests
    WHERE quote_requests.id = quotes.quote_request_id
    AND (quote_requests.user_id = auth.uid() OR auth.uid() IS NULL)
  )
);

-- ============================================
-- Verify all policies
-- ============================================

SELECT 'quote_items policies:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'quote_items'
ORDER BY policyname;

SELECT 'quotes policies:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'quotes'
ORDER BY policyname;

SELECT 'quote_request_items policies:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'quote_request_items'
ORDER BY policyname;

SELECT '✅ ALL RLS POLICIES FIXED!' as status;
SELECT 'Admin can now create quotes and quote_items' as result;
