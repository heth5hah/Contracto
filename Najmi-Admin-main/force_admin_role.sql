-- Force Admin Role - Quick Fix
-- Run this in Supabase SQL Editor to set your current user as admin
-- This bypasses RLS to ensure the update works

-- Method 1: Update current logged-in user (RECOMMENDED)
UPDATE public.users 
SET role = 'admin' 
WHERE id = auth.uid();

-- Verify it worked
SELECT 
    id,
    email,
    name,
    role,
    status
FROM public.users
WHERE id = auth.uid();

-- Method 2: If Method 1 doesn't work, update by email
-- Replace 'your-email@example.com' with your actual email
-- UPDATE public.users 
-- SET role = 'admin' 
-- WHERE email = 'your-email@example.com';

-- Method 3: Check all users and their roles
SELECT 
    id,
    email,
    name,
    role,
    status,
    created_at
FROM public.users
ORDER BY created_at DESC;

-- Method 4: Test if the is_admin function works for your user
SELECT 
    auth.uid() as current_user_id,
    public.is_admin(auth.uid()) as is_admin_result;

-- Method 5: If you need to set multiple users as admin
-- UPDATE public.users 
-- SET role = 'admin' 
-- WHERE email IN ('admin1@example.com', 'admin2@example.com');

