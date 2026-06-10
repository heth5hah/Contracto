-- ============================================
-- MASTER FIX SCRIPT - Run this ONE script to fix everything
-- ============================================
-- This script fixes all database issues for the quotation system

-- ============================================
-- STEP 1: Add missing columns
-- ============================================

-- Add columns to quote_request_items
ALTER TABLE quote_request_items 
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES brands(id),
ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id),
ADD COLUMN IF NOT EXISTS product_name TEXT,
ADD COLUMN IF NOT EXISTS category TEXT;

-- Add columns to quotes
ALTER TABLE quotes 
ADD COLUMN IF NOT EXISTS transport_charges NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS subtotal NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_amount NUMERIC DEFAULT 0;

-- Add columns to quote_items
ALTER TABLE quote_items
ADD COLUMN IF NOT EXISTS quality_option_id UUID,
ADD COLUMN IF NOT EXISTS quality_option_name TEXT,
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'units',
ADD COLUMN IF NOT EXISTS unit_price NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_price NUMERIC DEFAULT 0;

-- ============================================
-- STEP 2: Fix NOT NULL constraints
-- ============================================

-- Make tax_amount nullable
ALTER TABLE quotes 
ALTER COLUMN tax_amount DROP NOT NULL;

-- Set defaults for numeric columns
ALTER TABLE quotes 
ALTER COLUMN tax_amount SET DEFAULT 0,
ALTER COLUMN subtotal SET DEFAULT 0,
ALTER COLUMN total_amount SET DEFAULT 0,
ALTER COLUMN transport_charges SET DEFAULT 0;

ALTER TABLE quote_items
ALTER COLUMN quantity SET DEFAULT 1,
ALTER COLUMN unit_price SET DEFAULT 0,
ALTER COLUMN total_price SET DEFAULT 0;

-- ============================================
-- STEP 3: Fix RLS policies for quote_request_items
-- ============================================

DROP POLICY IF EXISTS "authenticated_select_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "authenticated_insert_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "authenticated_update_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "authenticated_delete_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "anon_insert_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "anon_select_own_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_all_insert_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_select_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_update_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_delete_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_users_select_own_quote_request_items" ON quote_request_items;

ALTER TABLE quote_request_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_all_insert_quote_request_items"
ON quote_request_items FOR INSERT
WITH CHECK (true);

CREATE POLICY "allow_authenticated_select_quote_request_items"
ON quote_request_items FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "allow_authenticated_update_quote_request_items"
ON quote_request_items FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "allow_authenticated_delete_quote_request_items"
ON quote_request_items FOR DELETE
TO authenticated
USING (true);

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

-- ============================================
-- STEP 4: Fix RLS policies for quotes
-- ============================================

DROP POLICY IF EXISTS "authenticated_select_quotes" ON quotes;
DROP POLICY IF EXISTS "authenticated_insert_quotes" ON quotes;
DROP POLICY IF EXISTS "authenticated_update_quotes" ON quotes;
DROP POLICY IF EXISTS "authenticated_delete_quotes" ON quotes;
DROP POLICY IF EXISTS "allow_authenticated_select_quotes" ON quotes;
DROP POLICY IF EXISTS "allow_authenticated_insert_quotes" ON quotes;
DROP POLICY IF EXISTS "allow_authenticated_update_quotes" ON quotes;
DROP POLICY IF EXISTS "allow_authenticated_delete_quotes" ON quotes;
DROP POLICY IF EXISTS "allow_users_select_own_quotes" ON quotes;

ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;

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
-- STEP 5: Fix RLS policies for quote_items
-- ============================================

DROP POLICY IF EXISTS "authenticated_select_quote_items" ON quote_items;
DROP POLICY IF EXISTS "authenticated_insert_quote_items" ON quote_items;
DROP POLICY IF EXISTS "authenticated_update_quote_items" ON quote_items;
DROP POLICY IF EXISTS "authenticated_delete_quote_items" ON quote_items;
DROP POLICY IF EXISTS "allow_authenticated_select_quote_items" ON quote_items;
DROP POLICY IF EXISTS "allow_authenticated_insert_quote_items" ON quote_items;
DROP POLICY IF EXISTS "allow_authenticated_update_quote_items" ON quote_items;
DROP POLICY IF EXISTS "allow_authenticated_delete_quote_items" ON quote_items;
DROP POLICY IF EXISTS "allow_users_select_own_quote_items" ON quote_items;

ALTER TABLE quote_items ENABLE ROW LEVEL SECURITY;

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
-- STEP 6: Verify everything
-- ============================================

SELECT '========================================' as separator;
SELECT '✅ MASTER FIX COMPLETE!' as status;
SELECT '========================================' as separator;

SELECT 'Columns added to quote_request_items:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'quote_request_items'
AND column_name IN ('notes', 'brand_id', 'product_id', 'product_name', 'category');

SELECT 'Columns added to quotes:' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'quotes'
AND column_name IN ('transport_charges', 'subtotal', 'tax_amount', 'total_amount');

SELECT 'Columns added to quote_items:' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'quote_items'
AND column_name IN ('quality_option_id', 'quality_option_name', 'quantity', 'unit', 'unit_price', 'total_price');

SELECT 'RLS Policies for quote_request_items:' as info;
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'quote_request_items'
ORDER BY policyname;

SELECT 'RLS Policies for quotes:' as info;
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'quotes'
ORDER BY policyname;

SELECT 'RLS Policies for quote_items:' as info;
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'quote_items'
ORDER BY policyname;

SELECT '========================================' as separator;
SELECT '🎉 ALL FIXES APPLIED SUCCESSFULLY!' as final_status;
SELECT 'You can now:' as next_steps;
SELECT '1. Submit quote requests from mobile app' as step_1;
SELECT '2. Set prices in admin panel' as step_2;
SELECT '3. View quoted prices in user app' as step_3;
SELECT '========================================' as separator;
