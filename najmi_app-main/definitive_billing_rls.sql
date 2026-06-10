-- =========================================================================
-- DEFINITIVE RLS FIX FOR BILLING CYCLES
-- Run this script in your Supabase SQL Editor
-- =========================================================================

-- 1. Create a secure function to check admin status (bypasses users RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    RETURN v_role = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Ensure RLS is enabled on billing_cycles
ALTER TABLE public.billing_cycles ENABLE ROW LEVEL SECURITY;

-- 3. Clean up any broken/old policies
DROP POLICY IF EXISTS "Enable read access for all users" ON public.billing_cycles;
DROP POLICY IF EXISTS "Enable update for admins" ON public.billing_cycles;
DROP POLICY IF EXISTS "Enable insert for admins" ON public.billing_cycles;
DROP POLICY IF EXISTS "Admins can do everything on billing_cycles" ON public.billing_cycles;
DROP POLICY IF EXISTS "Admins can update billing_cycles" ON public.billing_cycles;

-- 4. Policy: Anyone can READ billing cycles
CREATE POLICY "Enable read access for all users" 
ON public.billing_cycles FOR SELECT 
TO authenticated 
USING (true);

-- 5. Policy: Admins can UPDATE billing cycles
CREATE POLICY "Enable update for admins" 
ON public.billing_cycles FOR UPDATE 
TO authenticated 
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- 6. Policy: Admins can INSERT billing cycles
CREATE POLICY "Enable insert for admins" 
ON public.billing_cycles FOR INSERT 
TO authenticated 
WITH CHECK (public.is_admin());
