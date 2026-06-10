-- Fix Admin Access to Returns (Safe Version - Handles Existing Policies)
-- This adds/updates RLS policies so admins can view and manage all returns
-- Run this in Supabase SQL Editor

-- ============================================================================
-- ADD/UPDATE ADMIN POLICIES FOR RETURNS TABLE
-- ============================================================================

DO $$
BEGIN
    -- Drop existing policies if they exist (to recreate with correct definition)
    DROP POLICY IF EXISTS "Admins can view all returns" ON public.returns;
    DROP POLICY IF EXISTS "Admins can update all returns" ON public.returns;
    DROP POLICY IF EXISTS "Admins can delete all returns" ON public.returns;
    
    -- Allow admins to view ALL returns
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

    -- Allow admins to delete returns (if needed)
    CREATE POLICY "Admins can delete all returns" ON public.returns
        FOR DELETE USING (
            EXISTS (
                SELECT 1 FROM public.users 
                WHERE users.id = auth.uid() 
                AND users.role = 'admin'
            )
        );
END $$;

-- ============================================================================
-- ADD/UPDATE ADMIN POLICIES FOR RETURN_ITEMS TABLE
-- ============================================================================

DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Admins can view all return items" ON public.return_items;
    DROP POLICY IF EXISTS "Admins can update all return items" ON public.return_items;
    
    -- Allow admins to view ALL return items
    CREATE POLICY "Admins can view all return items" ON public.return_items
        FOR SELECT USING (
            EXISTS (
                SELECT 1 FROM public.users 
                WHERE users.id = auth.uid() 
                AND users.role = 'admin'
            )
        );

    -- Allow admins to update return items (if needed)
    CREATE POLICY "Admins can update all return items" ON public.return_items
        FOR UPDATE USING (
            EXISTS (
                SELECT 1 FROM public.users 
                WHERE users.id = auth.uid() 
                AND users.role = 'admin'
            )
        );
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check that admin policies were created
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename IN ('returns', 'return_items')
AND policyname LIKE '%Admin%'
ORDER BY tablename, policyname;

-- Expected output:
-- returns | Admins can view all returns | SELECT
-- returns | Admins can update all returns | UPDATE
-- returns | Admins can delete all returns | DELETE
-- return_items | Admins can view all return items | SELECT
-- return_items | Admins can update all return items | UPDATE

