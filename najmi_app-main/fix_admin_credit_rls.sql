-- Fix RLS policies for business credit tables to allow admins to perform operations

-- 1. Ensure the is_admin function exists and is SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    RETURN v_role = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admins can view all credit accounts" ON public.business_credit_accounts;
DROP POLICY IF EXISTS "Admins can insert credit accounts" ON public.business_credit_accounts;
DROP POLICY IF EXISTS "Admins can update credit accounts" ON public.business_credit_accounts;

DROP POLICY IF EXISTS "Admins can view all credit payments" ON public.credit_payments;
DROP POLICY IF EXISTS "Admins can insert credit payments" ON public.credit_payments;
DROP POLICY IF EXISTS "Admins can update credit payments" ON public.credit_payments;

DROP POLICY IF EXISTS "Admins can view all billing cycles" ON public.billing_cycles;
DROP POLICY IF EXISTS "Admins can insert billing cycles" ON public.billing_cycles;
DROP POLICY IF EXISTS "Admins can update billing cycles" ON public.billing_cycles;
DROP POLICY IF EXISTS "Enable update for admins" ON public.billing_cycles;
DROP POLICY IF EXISTS "Enable insert for admins" ON public.billing_cycles;

DROP POLICY IF EXISTS "Admins can view all credit_usage" ON public.credit_usage;
DROP POLICY IF EXISTS "Admins can insert credit_usage" ON public.credit_usage;

-- 3. Create proper policies on business_credit_accounts
CREATE POLICY "Admins can view all credit accounts" ON public.business_credit_accounts
    FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "Admins can insert credit accounts" ON public.business_credit_accounts
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update credit accounts" ON public.business_credit_accounts
    FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 4. Create proper policies on credit_payments
CREATE POLICY "Admins can view all credit payments" ON public.credit_payments
    FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "Admins can insert credit payments" ON public.credit_payments
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update credit payments" ON public.credit_payments
    FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 5. Create proper policies on billing_cycles
CREATE POLICY "Admins can view all billing cycles" ON public.billing_cycles
    FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "Admins can insert billing cycles" ON public.billing_cycles
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update billing cycles" ON public.billing_cycles
    FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 6. Create proper policies on credit_usage
CREATE POLICY "Admins can view all credit_usage" ON public.credit_usage
    FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "Admins can insert credit_usage" ON public.credit_usage
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());

SELECT 'SUCCESS: Admin RLS policies updated successfully!' AS result;
