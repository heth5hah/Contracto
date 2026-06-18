-- =========================================================================
-- SQL SCRIPT: Fix Pay and Accept, Business Credit, and RLS Recursion
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard)
-- =========================================================================

-- Step 1: Ensure basic schema usage privileges are granted
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon, service_role;

-- Step 2: Grant Table-level privileges to client roles
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.business_credit_accounts TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.credit_usage TO authenticated, anon;

GRANT ALL PRIVILEGES ON public.users TO service_role;
GRANT ALL PRIVILEGES ON public.business_credit_accounts TO service_role;
GRANT ALL PRIVILEGES ON public.credit_usage TO service_role;

-- Step 3: Recreate helper functions with secure path and owner privileges
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

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated, anon;


-- Step 4: Recreate RLS Policies on public.users
-- This prevents recursion by keeping SELECT policy completely simple (no function calls)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can browse users" ON public.users;
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update their own record" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;
DROP POLICY IF EXISTS "Admin full access" ON public.users;
DROP POLICY IF EXISTS "Admins have full access" ON public.users;
DROP POLICY IF EXISTS "Users can update own record if active" ON public.users;

-- SELECT is completely free of function calls to avoid any infinite loop recursion
CREATE POLICY "Anyone can browse users" ON public.users 
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own record" ON public.users 
    FOR INSERT TO authenticated, anon WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own record if active" ON public.users 
    FOR UPDATE TO authenticated USING (auth.uid() = id AND status = 'active') WITH CHECK (auth.uid() = id AND status = 'active');

-- Admins get non-recursive write access (since is_admin() runs a SELECT which has no recursion)
CREATE POLICY "Admin insert access" ON public.users FOR INSERT TO authenticated WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Admin update access" ON public.users FOR UPDATE TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Admin delete access" ON public.users FOR DELETE TO authenticated USING (public.is_admin(auth.uid()));


-- Step 5: Recreate RLS Policies on public.business_credit_accounts
-- This avoids querying public.users table for the current user's ID
ALTER TABLE public.business_credit_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own credit account" ON public.business_credit_accounts;
DROP POLICY IF EXISTS "Users can read own credit account" ON public.business_credit_accounts;
DROP POLICY IF EXISTS "Users can update own credit account" ON public.business_credit_accounts;
DROP POLICY IF EXISTS "Admins can manage credit accounts" ON public.business_credit_accounts;

CREATE POLICY "Users can read own credit account" ON public.business_credit_accounts
    FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Users can update own credit account" ON public.business_credit_accounts
    FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can manage credit accounts" ON public.business_credit_accounts
    FOR ALL TO authenticated USING (public.is_admin(auth.uid()));


-- Step 6: Recreate RLS Policies on public.credit_usage
ALTER TABLE public.credit_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own credit usage" ON public.credit_usage;
DROP POLICY IF EXISTS "Users can insert own credit usage" ON public.credit_usage;
DROP POLICY IF EXISTS "Admins can manage credit usage" ON public.credit_usage;

CREATE POLICY "Users can read own credit usage" ON public.credit_usage
    FOR SELECT TO authenticated USING (
        credit_account_id IN (SELECT id FROM public.business_credit_accounts WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can insert own credit usage" ON public.credit_usage
    FOR INSERT TO authenticated WITH CHECK (
        credit_account_id IN (SELECT id FROM public.business_credit_accounts WHERE user_id = auth.uid())
    );

CREATE POLICY "Admins can manage credit usage" ON public.credit_usage
    FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

-- Reload Schema Cache
NOTIFY pgrst, 'reload schema';

SELECT 'SUCCESS: Pay and accept RLS fix applied successfully!' AS result;
