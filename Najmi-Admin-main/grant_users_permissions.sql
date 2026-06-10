-- This fixes the root cause of the 42501 "permission denied" error.
-- The error is NOT an RLS issue. It means the "authenticated" role 
-- literally does not have the basic database privileges to read the users table.

GRANT SELECT ON public.users TO authenticated;
GRANT SELECT ON public.users TO anon;
GRANT SELECT ON public.users TO service_role;

-- Also re-apply the simplest RLS policy just in case
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON public.users;
CREATE POLICY "Enable read access for all authenticated users" ON public.users FOR SELECT USING (
  auth.role() = 'authenticated'
);
