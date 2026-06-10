-- Fix RLS policies for credit_usage to prevent 'permission denied for table users'
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

-- 2. Enable RLS on credit_usage
ALTER TABLE public.credit_usage ENABLE ROW LEVEL SECURITY;

-- 2.5 Ensure the base table permissions are granted
GRANT SELECT ON public.users TO authenticated;
GRANT SELECT ON public.credit_usage TO authenticated;

-- 3. Drop all existing policies on credit_usage to clear out bad ones
DROP POLICY IF EXISTS "Enable read access for all users" ON public.credit_usage;
DROP POLICY IF EXISTS "Users can view their own credit usage" ON public.credit_usage;
DROP POLICY IF EXISTS "Users can read own credit usage" ON public.credit_usage;
DROP POLICY IF EXISTS "Admins can view all credit usage" ON public.credit_usage;
DROP POLICY IF EXISTS "Admins can view all credit_usage" ON public.credit_usage;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.credit_usage;
DROP POLICY IF EXISTS "Enable update for admins" ON public.credit_usage;

-- 4. Create proper policies using SECURITY DEFINER functions or simple checks
-- Admins can read all credit_usage
CREATE POLICY "Admins can view all credit_usage" 
ON public.credit_usage FOR SELECT
TO authenticated 
USING (public.is_admin());

-- Users can read their own (joining through business_credit_accounts)
CREATE POLICY "Users can read own credit usage"
ON public.credit_usage FOR SELECT
TO authenticated
USING (
  credit_account_id IN (
    SELECT id FROM public.business_credit_accounts WHERE user_id = auth.uid()
  ) OR public.is_admin()
);

-- Note: The insertion to credit_usage is typically done via SECURITY DEFINER RPCs 
-- (like deduct_business_credit or process_return_refund), so we don't necessarily 
-- need complex INSERT policies for regular users.

-- Also ensure 'users' table is readable by admins safely
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users"
ON public.users FOR SELECT
TO authenticated
USING (public.is_admin() OR id = auth.uid());
