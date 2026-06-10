-- Check what role the admin user has
SELECT id, email, role FROM users WHERE email = 'burhan@contractobuild.com';

-- Check current RLS policies on notifications
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'notifications';
