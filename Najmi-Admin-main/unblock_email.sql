-- UNBLOCK EMAIL SCRIPT
-- Run this script in the Supabase SQL Editor to remove an email from the blocklist
-- so it can be registered again.

-- 1. Remove the email from the blocked list
DELETE FROM public.blocked_emails 
WHERE email = 'shaheth555@gmail.com';

-- 2. Also remove any "_deleted_" versions of this email from the blocklist just in case
DELETE FROM public.blocked_emails 
WHERE email LIKE 'shaheth555@gmail.com_deleted_%';

-- 3. Make sure the public.users record is fully scrambled and doesn't hold the original email
UPDATE public.users 
SET email = email || '_deleted_' || gen_random_uuid()::text
WHERE email = 'shaheth555@gmail.com';
