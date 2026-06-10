-- =========================================================================
-- FIX BILLING CYCLES RLS FOR ADMIN
-- Run this script in your Supabase SQL Editor
-- =========================================================================

-- Enable RLS on the billing_cycles table just in case it's not
ALTER TABLE public.billing_cycles ENABLE ROW LEVEL SECURITY;

-- 1. Drop existing admin update policies if any to avoid conflicts
DROP POLICY IF EXISTS "Admins can do everything on billing_cycles" ON public.billing_cycles;
DROP POLICY IF EXISTS "Admins can update billing_cycles" ON public.billing_cycles;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.billing_cycles;
DROP POLICY IF EXISTS "Enable update for admins" ON public.billing_cycles;

-- 2. Create a policy that allows ALL authenticated users to read billing cycles
CREATE POLICY "Enable read access for all users" 
ON public.billing_cycles FOR SELECT 
TO authenticated 
USING (true);

-- 3. Create a policy that allows Admins to update billing cycles
CREATE POLICY "Enable update for admins" 
ON public.billing_cycles FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND users.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND users.role = 'admin'
  )
);

-- 4. Create a policy that allows Admins to insert billing cycles
CREATE POLICY "Enable insert for admins" 
ON public.billing_cycles FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND users.role = 'admin'
  )
);
