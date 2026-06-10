-- COMPREHENSIVE FIX for user profile updates
-- Run this in Supabase SQL Editor

-- Step 1: Drop all existing update policies for users table
DROP POLICY IF EXISTS "Users can update their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Admins can update any user" ON public.users;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.users;

-- Step 2: Create a more permissive update policy for authenticated users
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE 
    TO authenticated
    USING (
        id = auth.uid() 
        OR 
        email = auth.jwt()->>'email'
    )
    WITH CHECK (
        id = auth.uid() 
        OR 
        email = auth.jwt()->>'email'
    );

-- Step 3: Fix SELECT policy to work with email too
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
CREATE POLICY "Users can read their own record" ON public.users
    FOR SELECT 
    TO authenticated
    USING (
        id = auth.uid() 
        OR 
        email = auth.jwt()->>'email'
    );

-- Step 4: Grant permissions
GRANT UPDATE ON public.users TO authenticated;
GRANT SELECT ON public.users TO authenticated;

-- Step 5: Verify policies were created
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'users';
