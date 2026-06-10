-- Comprehensive Test Script for Users Access
-- Run this in Supabase SQL Editor to diagnose the issue

-- Step 1: Check if you're authenticated
SELECT 
    auth.uid() as current_user_id,
    auth.email() as current_email;

-- Step 2: Check your user record and role
SELECT 
    id,
    email,
    name,
    role,
    status,
    created_at
FROM public.users
WHERE id = auth.uid();

-- Step 3: Check if is_admin function works for you
SELECT 
    auth.uid() as user_id,
    public.is_admin(auth.uid()) as is_admin_result;

-- Step 4: Count total users in database (should work regardless of RLS)
-- This uses a SECURITY DEFINER function to bypass RLS
CREATE OR REPLACE FUNCTION public.count_all_users()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT COUNT(*)::INTEGER FROM public.users;
$$;

SELECT public.count_all_users() as total_users_in_db;

-- Step 5: Try to see all users (this will be blocked by RLS if not admin)
SELECT 
    id,
    email,
    name,
    role,
    status
FROM public.users
ORDER BY created_at DESC
LIMIT 10;

-- Step 6: Check RLS policies
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

-- Step 7: If is_admin returns false, force set as admin
DO $$
BEGIN
    IF NOT public.is_admin(auth.uid()) THEN
        UPDATE public.users 
        SET role = 'admin' 
        WHERE id = auth.uid();
        
        RAISE NOTICE 'Updated your role to admin. Please refresh and try again.';
    ELSE
        RAISE NOTICE 'You are already an admin. If you still cannot see users, check RLS policies.';
    END IF;
END $$;

-- Step 8: Verify the update
SELECT 
    id,
    email,
    role,
    public.is_admin(id) as is_admin_check
FROM public.users
WHERE id = auth.uid();

