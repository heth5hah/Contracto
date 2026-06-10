-- The simplest and most robust fix to prevent the 42501 error when doing Joins with users table
DROP POLICY IF EXISTS "admin_read_all_users" ON public.users;
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON public.users;

CREATE POLICY "Enable read access for all authenticated users" ON public.users FOR SELECT USING (
  auth.role() = 'authenticated'
);
