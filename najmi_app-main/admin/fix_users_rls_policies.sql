-- Fix RLS policies for users table to allow registration
-- This script creates the necessary policies for user registration and management

-- First, check if RLS is enabled (it likely is)
-- If you need to disable it temporarily for testing, uncomment the next line:
-- ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Enable RLS on users table (if not already enabled)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update their own record" ON public.users;
DROP POLICY IF EXISTS "Admins can read all users" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.users;
DROP POLICY IF EXISTS "Enable read for authenticated users" ON public.users;

-- Create policy to allow users to insert their own records during registration
-- This is crucial for the registration process to work
CREATE POLICY "Users can insert their own record" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Create policy to allow users to read their own record
CREATE POLICY "Users can read their own record" ON public.users
    FOR SELECT USING (auth.uid() = id);

-- Create policy to allow users to update their own record
CREATE POLICY "Users can update their own record" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- Create policy to allow admins to read all users
CREATE POLICY "Admins can read all users" ON public.users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Create policy to allow admins to update any user
CREATE POLICY "Admins can update any user" ON public.users
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Grant necessary permissions on the users table
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.users TO anon;

-- Also grant permissions on the sequence (for auto-generated IDs)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Verify the policies are created
SELECT 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual, 
    with_check
FROM pg_policies 
WHERE tablename = 'users';

-- Show success message
DO $$
BEGIN
    RAISE NOTICE 'RLS policies created successfully for users table!';
    RAISE NOTICE 'Users should now be able to register without RLS violations.';
END $$;
