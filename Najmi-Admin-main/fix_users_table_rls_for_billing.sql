-- =========================================================================
-- FIX PERMISSION DENIED FOR USERS TABLE IN BUSINESS BILLING
-- Run this script in your Supabase SQL Editor
-- =========================================================================

-- 1. Ensure RLS is enabled on users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2. Grant necessary permissions to authenticated users to access the table
GRANT SELECT ON public.users TO authenticated;
GRANT SELECT ON public.users TO anon;

-- 3. Create or replace a function to check if the current user is an admin
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    RETURN v_role = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Drop potentially conflicting policies
DROP POLICY IF EXISTS "Admins can read all users" ON public.users;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.users;
DROP POLICY IF EXISTS "Admins can do everything" ON public.users;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.users;

-- 5. Create policy to allow reading users for authenticated users
--    In many apps, users need to see basic user info, or admins need to see all.
--    We allow authenticated users to read all user records. 
--    (If you only want admins, you can change 'true' to 'public.check_is_admin()')
CREATE POLICY "Enable read access for authenticated users" 
ON public.users FOR SELECT 
TO authenticated 
USING (true);

-- 6. Also ensure business_credit_accounts has read access
ALTER TABLE public.business_credit_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.business_credit_accounts;
CREATE POLICY "Enable read access for all users" 
ON public.business_credit_accounts FOR SELECT 
TO authenticated 
USING (true);

-- 7. Force Supabase API to reload its schema cache just in case
NOTIFY pgrst, 'reload schema';
