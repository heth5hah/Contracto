-- TEMPORARY: Disable RLS on users table for testing
-- ⚠️ WARNING: This removes security! Only use for testing!
-- Run this to temporarily disable RLS and see if that's the issue

-- Step 1: Disable RLS temporarily
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Step 2: Test if you can now see users
SELECT COUNT(*) as total_users FROM public.users;
SELECT id, email, name, role FROM public.users LIMIT 5;

-- Step 3: If this works, the issue is with RLS policies
-- Step 4: Re-enable RLS after testing
-- ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Step 5: Then fix the policies using admin_users_rls_policies.sql

