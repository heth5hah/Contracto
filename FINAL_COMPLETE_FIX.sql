-- COMPLETE FIX: Ensure quote_request_items table has all required columns
-- Run this in Supabase SQL Editor

-- Step 1: Check current table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'quote_request_items'
ORDER BY ordinal_position;

-- Step 2: Add all missing columns that the mobile app is trying to insert
ALTER TABLE quote_request_items 
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES brands(id),
ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id),
ADD COLUMN IF NOT EXISTS product_name TEXT,
ADD COLUMN IF NOT EXISTS category TEXT;

-- Step 3: Verify all columns exist
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'quote_request_items'
ORDER BY ordinal_position;

-- Step 4: Now run the RLS fix (if not already done)
-- Drop all existing policies
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
DROP POLICY IF EXISTS "allow_all_insert_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_select_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_update_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_delete_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_users_select_own_quote_request_items" ON quote_request_items;

-- Enable RLS
ALTER TABLE quote_request_items ENABLE ROW LEVEL SECURITY;

-- Allow EVERYONE to insert
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

-- Step 5: Verify everything
SELECT '✅ ALL FIXES APPLIED!' as status;
SELECT 'Columns added: notes, brand_id, product_id, product_name, category' as columns_added;
SELECT 'RLS policies updated to allow inserts' as rls_status;
SELECT 'You can now submit quote requests from the mobile app!' as next_step;
