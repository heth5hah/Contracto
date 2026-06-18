-- =========================================================================
-- SQL SCRIPT: Fix permissions and RLS policies on public.users table
-- Run this script in your Supabase SQL Editor (https://supabase.com/dashboard)
-- =========================================================================

-- Step 1: Grant Schema and Sequence privileges
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon, service_role;

-- Step 2: Grant Table-level privileges to roles
-- This resolves the "permission denied for table users" (42501 / 403 Forbidden)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO anon;
GRANT ALL PRIVILEGES ON public.users TO service_role;

-- Step 3: Recreate the admin helper functions safely (SECURITY DEFINER + search_path)
-- This avoids RLS infinite recursion when policies query public.users
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;
    
    SELECT role INTO v_role FROM public.users WHERE id = v_uid;
    RETURN LOWER(v_role) = 'admin';
END;
$$;

CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
BEGIN
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    SELECT role INTO v_role FROM public.users WHERE id = user_id;
    RETURN LOWER(v_role) = 'admin';
END;
$$;

-- Grant execution rights on functions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated, anon;

-- Step 4: Drop all existing RLS policies on users table to prevent conflicts
DROP POLICY IF EXISTS "Anyone can browse users" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own record if active" ON public.users;
DROP POLICY IF EXISTS "Admin full access" ON public.users;
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
DROP POLICY IF EXISTS "Admins can read all users" ON public.users;
DROP POLICY IF EXISTS "Admins can update any user" ON public.users;
DROP POLICY IF EXISTS "Admins can delete any user" ON public.users;
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

-- Step 5: Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Step 6: Create new clean, recursive-free policies
-- 6a. Users can select their own record
CREATE POLICY "Users can read their own record" ON public.users
    FOR SELECT
    TO authenticated, anon
    USING (auth.uid() = id OR email = auth.jwt()->>'email');

-- 6b. Users can update their own record
CREATE POLICY "Users can update their own record" ON public.users
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id AND status = 'active')
    WITH CHECK (auth.uid() = id AND status = 'active');

-- 6c. Users can insert their own record (during signup/registration)
CREATE POLICY "Users can insert their own record" ON public.users
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (auth.uid() = id OR email = auth.jwt()->>'email');

-- 6d. Admins have full access to all records
CREATE POLICY "Admins have full access" ON public.users
    FOR ALL
    TO authenticated
    USING (public.is_admin() OR public.is_admin(auth.uid()))
    WITH CHECK (public.is_admin() OR public.is_admin(auth.uid()));

-- Step 7: Verify policies on the table
SELECT policyname, cmd, roles FROM pg_policies WHERE tablename = 'users';
