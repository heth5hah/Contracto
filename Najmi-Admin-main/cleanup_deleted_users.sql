-- FINAL SOLUTION: Handle User Deletions Automatically
-- This script fixes orphaned user records and prevents the issue from happening again.

-- 1. First, fix any currently orphaned records (like shaheth555@gmail.com)
-- This finds users in public.users that no longer exist in auth.users
-- and renames their email so the email can be used again for registration.
UPDATE public.users pu
SET 
    email = pu.email || '_deleted_' || gen_random_uuid()::text,
    status = 'deleted'
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users au WHERE au.id = pu.id
);

-- 2. Create an automatic trigger for FUTURE deletions
-- When you delete a user from the Supabase Auth Dashboard, this trigger
-- will automatically update their public.users record to free up the email.
CREATE OR REPLACE FUNCTION public.handle_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- We don't hard-delete from public.users to preserve order history and foreign keys.
  -- Instead, we soft-delete them and scramble the email so it can be re-registered.
  UPDATE public.users 
  SET 
      email = email || '_deleted_' || gen_random_uuid()::text,
      status = 'deleted'
  WHERE id = old.id;
  
  RETURN old;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach the trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;
CREATE TRIGGER on_auth_user_deleted
  AFTER DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_user_deletion();
