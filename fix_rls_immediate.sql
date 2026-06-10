-- IMMEDIATE FIX: Admin Returns Access
-- Run this NOW in Supabase SQL Editor

-- ============================================================================
-- CRITICAL: Verify your admin role first
-- ============================================================================
SELECT id, email, role FROM users WHERE id = auth.uid();

-- If role is NOT 'admin', run this:
-- UPDATE users SET role = 'admin' WHERE id = auth.uid();

-- ============================================================================
-- Drop and recreate ALL return policies
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Admins can view all returns" ON public.returns;
DROP POLICY IF EXISTS "Admins can update all returns" ON public.returns;
DROP POLICY IF EXISTS "Admins can delete all returns" ON public.returns;
DROP POLICY IF EXISTS "Users can view their own returns" ON public.returns;
DROP POLICY IF EXISTS "Users can create their own returns" ON public.returns;
DROP POLICY IF EXISTS "Users can update their own pending returns" ON public.returns;

DROP POLICY IF EXISTS "Admins can view all return items" ON public.return_items;
DROP POLICY IF EXISTS "Admins can update all return items" ON public.return_items;
DROP POLICY IF EXISTS "Users can view their return items" ON public.return_items;
DROP POLICY IF EXISTS "Users can create return items" ON public.return_items;

-- ============================================================================
-- Recreate user policies (for customers)
-- ============================================================================

CREATE POLICY "Users can view their own returns" ON public.returns
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own returns" ON public.returns
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pending returns" ON public.returns
    FOR UPDATE USING (auth.uid() = user_id AND return_status = 'pending');

CREATE POLICY "Users can view their return items" ON public.return_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.returns 
            WHERE returns.id = return_items.return_id 
            AND returns.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create return items" ON public.return_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.returns 
            WHERE returns.id = return_items.return_id 
            AND returns.user_id = auth.uid()
        )
    );

-- ============================================================================
-- Create admin policies (MUST come after user policies)
-- ============================================================================

-- Admin can view ALL returns (overrides user restriction)
CREATE POLICY "Admins can view all returns" ON public.returns
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Admin can update ALL returns
CREATE POLICY "Admins can update all returns" ON public.returns
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Admin can delete returns
CREATE POLICY "Admins can delete all returns" ON public.returns
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Admin can view ALL return items
CREATE POLICY "Admins can view all return items" ON public.return_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Admin can update return items
CREATE POLICY "Admins can update all return items" ON public.return_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- ============================================================================
-- VERIFY: Test the query
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

-- Expected: Should return 1 row

-- ============================================================================
-- VERIFY: Check all policies
-- ============================================================================

SELECT 
    tablename, 
    policyname, 
    cmd
FROM pg_policies 
WHERE tablename IN ('returns', 'return_items')
ORDER BY tablename, policyname;

