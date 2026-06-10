-- Diagnostic and Fix Script for Admin User Access
-- Run this in your Supabase SQL Editor to check and fix admin access

-- Step 1: Check current user and their role
SELECT 
    id,
    email,
    name,
    role,
    status
FROM public.users
WHERE id = auth.uid();

-- Step 2: Check if there are any users in the database
SELECT COUNT(*) as total_users FROM public.users;

-- Step 3: List all users and their roles
SELECT 
    id,
    email,
    name,
    role,
    status,
    created_at
FROM public.users
ORDER BY created_at DESC
LIMIT 10;

-- Step 4: Check if the is_admin function exists and works
SELECT public.is_admin(auth.uid()) as is_current_user_admin;

-- Step 5: If your user doesn't have admin role, update it
-- UNCOMMENT THE LINE BELOW AND REPLACE 'YOUR-EMAIL@example.com' WITH YOUR ACTUAL EMAIL
-- UPDATE public.users SET role = 'admin' WHERE email = 'YOUR-EMAIL@example.com';

-- OR update the currently logged-in user:
UPDATE public.users 
SET role = 'admin' 
WHERE id = auth.uid();

-- Step 6: Verify the update
SELECT 
    id,
    email,
    name,
    role
FROM public.users
WHERE id = auth.uid();

-- Step 7: Test if admin can see all users (should return all users)
SELECT COUNT(*) as visible_users_count
FROM public.users;

-- Step 8: Check RLS policies
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

