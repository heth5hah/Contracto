-- Final Fix for Admin Returns Access
-- This ensures admins can see ALL returns
-- Run this in Supabase SQL Editor

-- ============================================================================
-- STEP 1: DROP ALL EXISTING ADMIN POLICIES (Clean Slate)
-- ============================================================================

DROP POLICY IF EXISTS "Admins can view all returns" ON public.returns;
DROP POLICY IF EXISTS "Admins can update all returns" ON public.returns;
DROP POLICY IF EXISTS "Admins can delete all returns" ON public.returns;
DROP POLICY IF EXISTS "Admins can view all return items" ON public.return_items;
DROP POLICY IF EXISTS "Admins can update all return items" ON public.return_items;

-- ============================================================================
-- STEP 2: CREATE ADMIN POLICIES FOR RETURNS TABLE
-- ============================================================================

-- Allow admins to view ALL returns (no user_id restriction)
CREATE POLICY "Admins can view all returns" ON public.returns
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Allow admins to update ALL returns
CREATE POLICY "Admins can update all returns" ON public.returns
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Allow admins to delete returns
CREATE POLICY "Admins can delete all returns" ON public.returns
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- ============================================================================
-- STEP 3: CREATE ADMIN POLICIES FOR RETURN_ITEMS TABLE
-- ============================================================================

-- Allow admins to view ALL return items
CREATE POLICY "Admins can view all return items" ON public.return_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Allow admins to update return items
CREATE POLICY "Admins can update all return items" ON public.return_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- ============================================================================
-- STEP 4: VERIFY YOUR ADMIN ROLE
-- ============================================================================

-- Check your current role
SELECT id, email, role FROM users WHERE id = auth.uid();

-- If not admin, set it (replace with your actual user ID if needed)
-- UPDATE users SET role = 'admin' WHERE id = auth.uid();

-- ============================================================================
-- STEP 5: VERIFY POLICIES WERE CREATED
-- ============================================================================

SELECT 
    tablename, 
    policyname, 
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('returns', 'return_items')
AND policyname LIKE '%Admin%'
ORDER BY tablename, policyname;

-- ============================================================================
-- STEP 6: TEST QUERY (Should return results if you're admin)
-- ============================================================================

-- This should return the return request if you're admin
SELECT 
    r.id,
    r.order_id,
    r.return_status,
    r.refund_amount,
    r.created_at
FROM returns r
WHERE r.order_id = '51b4004e-7735-41c3-b687-e0699f48429a';

-- Expected: Should return 1 row with the return request

