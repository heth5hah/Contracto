-- Fix RLS policies for Admin Panel to access users table
-- Run this in your Supabase SQL Editor
-- This allows admin users to view and manage all users

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own data" ON public.users;
DROP POLICY IF EXISTS "Users can update their own data" ON public.users;
DROP POLICY IF EXISTS "Anyone can insert during registration" ON public.users;
DROP POLICY IF EXISTS "Admins can read all users" ON public.users;
DROP POLICY IF EXISTS "Admins can update any user" ON public.users;
DROP POLICY IF EXISTS "Admins can delete any user" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update their own record" ON public.users;

-- Drop the function if it exists (to recreate it)
DROP FUNCTION IF EXISTS public.is_admin(UUID);

-- Enable RLS on users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow users to insert their own records during registration
CREATE POLICY "Users can insert their own record" ON public.users
    FOR INSERT 
    WITH CHECK (auth.uid() = id);

-- Policy 2: Allow users to read their own record
CREATE POLICY "Users can read their own record" ON public.users
    FOR SELECT 
    USING (auth.uid() = id);

-- Policy 3: Allow users to update their own record
CREATE POLICY "Users can update their own record" ON public.users
    FOR UPDATE 
    USING (auth.uid() = id);

-- Create a function to check if user is admin (bypasses RLS)
-- SECURITY DEFINER allows the function to run with elevated privileges
-- This bypasses RLS automatically when the function runs
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = user_id AND LOWER(role) = 'admin'
    );
$$;

-- Policy 4: Allow admins to read ALL users
-- Uses the function to avoid infinite recursion
CREATE POLICY "Admins can read all users" ON public.users
    FOR SELECT 
    USING (public.is_admin(auth.uid()));

-- Policy 5: Allow admins to update any user
CREATE POLICY "Admins can update any user" ON public.users
    FOR UPDATE 
    USING (public.is_admin(auth.uid()))
    WITH CHECK (public.is_admin(auth.uid()));

-- Policy 6: Allow admins to delete any user (if needed)
CREATE POLICY "Admins can delete any user" ON public.users
    FOR DELETE 
    USING (public.is_admin(auth.uid()));

-- Grant necessary permissions
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.users TO anon;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO anon;

-- Verify the policies are created
SELECT 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY policyname;

-- Show success message
DO $$
BEGIN
    RAISE NOTICE 'RLS policies created successfully for users table!';
    RAISE NOTICE 'Admin users can now view and manage all users.';
    RAISE NOTICE 'Make sure your admin user has role = ''admin'' in the users table.';
END $$;

