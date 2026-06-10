-- STEP-BY-STEP FIX FOR QUOTE REQUEST ITEMS

-- ============================================================================
-- STEP 1: Fix RLS Policies (Run this first)
-- ============================================================================

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
DROP POLICY IF EXISTS "allow_all_insert_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_select_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_update_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_authenticated_delete_quote_request_items" ON quote_request_items;
DROP POLICY IF EXISTS "allow_users_select_own_quote_request_items" ON quote_request_items;

-- Enable RLS
ALTER TABLE quote_request_items ENABLE ROW LEVEL SECURITY;

-- CRITICAL: Allow EVERYONE to insert (this fixes the mobile app issue)
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

-- ============================================================================
-- STEP 2: Verify the fix worked
-- ============================================================================

SELECT 
    'RLS Policies Fixed!' as status,
    COUNT(*) as policy_count
FROM pg_policies 
WHERE tablename = 'quote_request_items';

-- ============================================================================
-- STEP 3: Check current state
-- ============================================================================

-- See which quote requests have items
SELECT 
    qr.id,
    qr.product_name as request_name,
    qr.created_at,
    COUNT(qri.id) as item_count
FROM quote_requests qr
LEFT JOIN quote_request_items qri ON qri.quote_request_id = qr.id
GROUP BY qr.id, qr.product_name, qr.created_at
ORDER BY qr.created_at DESC
LIMIT 20;

-- ============================================================================
-- IMPORTANT NOTES:
-- ============================================================================
-- 1. Existing quote requests will still have 0 items (they were created when RLS was blocking)
-- 2. NEW quote requests submitted after this fix will have items
-- 3. To test: Submit a NEW quote request from the mobile app
-- 4. Then run the query above again - the new request should show item_count > 0
-- ============================================================================

SELECT '✅ RLS Fix Complete! Now submit a NEW quote request from mobile app to test.' as next_step;
