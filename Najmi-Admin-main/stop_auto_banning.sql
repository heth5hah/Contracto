-- FIX FOR AUTOMATIC EMAIL BANNING ON DELETE
-- Run this in your Supabase SQL Editor

-- 1. Remove the trigger logic that auto-bans deleted accounts.
--    We only want to ban accounts if their status is explicitly set to 'blocked'.
CREATE OR REPLACE FUNCTION public.sync_blocked_emails()
RETURNS TRIGGER AS $$
BEGIN
    -- If status changed to blocked, add to blocklist
    IF (TG_OP = 'UPDATE' AND NEW.status = 'blocked') THEN
        INSERT INTO public.blocked_emails (email, reason)
        VALUES (NEW.email, 'Blocked by Admin')
        ON CONFLICT (email) DO NOTHING;
    END IF;
    
    -- REMOVED: The logic that automatically banned OLD.email when a row was DELETED.
    -- REMOVED: The logic that automatically banned NEW.email when status was 'deleted'.
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Clear out your email from the blocklist so you can register right now
DELETE FROM public.blocked_emails 
WHERE email = 'shaheth555@gmail.com' 
   OR email LIKE 'shaheth555@gmail.com_deleted_%'
   OR email LIKE 'deleted_%@deleted.com';

-- 3. If there are any completely orphaned records, scramble their emails so they don't block
UPDATE public.users pu
SET email = pu.email || '_deleted_' || gen_random_uuid()::text
WHERE NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = pu.id);
