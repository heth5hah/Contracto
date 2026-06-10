-- ===========================================================================
-- FINAL FIX: User Re-Registration After Deletion + No Auto 5-Lakh Credit
-- Run this ENTIRE script in your Supabase SQL Editor in ONE go.
-- ===========================================================================

-- ========================
-- PART 1: FIX EMAIL BANNING
-- ========================

-- 1a. Update sync_blocked_emails to ONLY ban on explicit admin "blocked" action
--     REMOVE: auto-ban on DELETE and on status='deleted'
CREATE OR REPLACE FUNCTION public.sync_blocked_emails()
RETURNS TRIGGER AS $$
BEGIN
    -- ONLY block if admin explicitly sets status to 'blocked'
    IF (TG_OP = 'UPDATE' AND NEW.status = 'blocked') THEN
        INSERT INTO public.blocked_emails (email, reason)
        VALUES (NEW.email, 'Blocked by Admin')
        ON CONFLICT (email) DO NOTHING;
    END IF;
    
    -- If admin UN-blocks (changes from 'blocked' to 'active'), remove from blocklist
    IF (TG_OP = 'UPDATE' AND OLD.status = 'blocked' AND NEW.status = 'active') THEN
        DELETE FROM public.blocked_emails WHERE email = NEW.email;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1b. Clear the ENTIRE blocklist of non-admin-blocked entries
--     (Only keep entries that were explicitly "Blocked by Admin")
DELETE FROM public.blocked_emails 
WHERE reason IS DISTINCT FROM 'Blocked by Admin';

-- 1c. Also specifically remove shaheth555@gmail.com in case it was "Blocked by Admin"
DELETE FROM public.blocked_emails 
WHERE email = 'shaheth555@gmail.com';

-- 1d. Scramble emails of orphaned public.users records so they don't cause
--     unique constraint violations when the user re-registers
UPDATE public.users pu
SET 
    email = pu.email || '_deleted_' || gen_random_uuid()::text,
    status = 'deleted'
WHERE NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = pu.id)
  AND pu.email NOT LIKE '%_deleted_%';

-- 1e. Also scramble mobile/gst/pan of orphaned records to free up those unique slots
UPDATE public.users pu
SET 
    mobile = pu.mobile || '_del_' || gen_random_uuid()::text,
    gst_number = CASE WHEN pu.gst_number IS NOT NULL THEN pu.gst_number || '_del' ELSE NULL END,
    pan = CASE WHEN pu.pan IS NOT NULL THEN pu.pan || '_del' ELSE NULL END
WHERE NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = pu.id)
  AND pu.status = 'deleted'
  AND pu.mobile NOT LIKE '%_del_%';


-- ========================
-- PART 2: FIX AUTO-DELETION TRIGGER
-- ========================
-- When a user is deleted from Supabase Auth Dashboard, scramble their
-- public.users email/mobile so the same email can be used to re-register.
-- Do NOT add to blocked_emails.

CREATE OR REPLACE FUNCTION public.handle_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Soft-delete: scramble unique fields so email/mobile/gst/pan can be reused
  UPDATE public.users 
  SET 
      email = email || '_deleted_' || gen_random_uuid()::text,
      mobile = mobile || '_del_' || gen_random_uuid()::text,
      gst_number = CASE WHEN gst_number IS NOT NULL THEN gst_number || '_del' ELSE NULL END,
      pan = CASE WHEN pan IS NOT NULL THEN pan || '_del' ELSE NULL END,
      status = 'deleted'
  WHERE id = old.id;
  
  -- IMPORTANT: Do NOT insert into blocked_emails here!
  -- Deletion should allow re-registration.
  
  RETURN old;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach the trigger
DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;
CREATE TRIGGER on_auth_user_deleted
  AFTER DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_user_deletion();


-- ========================
-- PART 3: FIX handle_new_user (auth trigger)
-- ========================
-- When a new user signs up via Supabase Auth, create their public.users record.
-- Skip if blocked. Handle duplicate fields gracefully.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- SKIP if email is explicitly blocked by admin
  IF EXISTS (SELECT 1 FROM public.blocked_emails WHERE email = new.email) THEN
    RETURN new;
  END IF;

  -- Insert into public.users ONLY if no unique conflicts exist
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE email = new.email AND status != 'deleted') THEN
    -- Also check mobile conflicts (only against active records)
    IF (new.raw_user_meta_data->>'mobile') IS NOT NULL 
       AND EXISTS (SELECT 1 FROM public.users WHERE mobile = new.raw_user_meta_data->>'mobile' AND status != 'deleted') THEN
        RETURN new;
    END IF;
    
    -- Check GST conflicts
    IF (new.raw_user_meta_data->>'gst_number') IS NOT NULL 
       AND EXISTS (SELECT 1 FROM public.users WHERE gst_number = new.raw_user_meta_data->>'gst_number' AND status != 'deleted') THEN
        RETURN new;
    END IF;

    INSERT INTO public.users (
      id, email, name, mobile, user_type, company_name, gst_number, pan_number, 
      is_gst_registered, credit_limit, status, role, created_at
    )
    VALUES (
      new.id,
      new.email,
      COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
      COALESCE(new.raw_user_meta_data->>'mobile', ''),
      COALESCE(new.raw_user_meta_data->>'user_type', 'individual'),
      new.raw_user_meta_data->>'company_name',
      new.raw_user_meta_data->>'gst_number',
      new.raw_user_meta_data->>'pan_number',
      (CASE WHEN (new.raw_user_meta_data->>'gst_number') IS NOT NULL 
            AND (new.raw_user_meta_data->>'gst_number') <> '' THEN true ELSE false END),
      0,           -- credit_limit = 0 (admin must grant)
      'active',
      'customer',
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ========================
-- PART 4: FIX handle_user_profile RPC
-- ========================
-- Called by the app on first login. Creates user profile + credit account.
-- Credit account should start as PENDING with 0 limit (NOT 500000).

DROP FUNCTION IF EXISTS public.handle_user_profile(uuid,text,text,text,text,text,text,text);

CREATE OR REPLACE FUNCTION public.handle_user_profile(
    p_user_id UUID,
    p_email TEXT,
    p_name TEXT,
    p_mobile TEXT,
    p_user_type TEXT DEFAULT 'individual',
    p_company_name TEXT DEFAULT NULL,
    p_gst_number TEXT DEFAULT NULL,
    p_pan_number TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Upsert into public.users
    INSERT INTO public.users (
        id, email, name, mobile, user_type, company_name, gst_number, pan_number, 
        credit_limit, status, role
    )
    VALUES (
        p_user_id, p_email, p_name, p_mobile, p_user_type, p_company_name, 
        p_gst_number, p_pan_number, 0, 'active', 'customer'
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        mobile = EXCLUDED.mobile,
        user_type = EXCLUDED.user_type,
        company_name = EXCLUDED.company_name,
        gst_number = EXCLUDED.gst_number,
        pan_number = EXCLUDED.pan_number
    WHERE users.status = 'active';

    -- For business/company users, create a PENDING credit account with 0 limit
    -- Admin must manually activate and set the credit limit
    IF p_user_type = 'company' THEN
        INSERT INTO public.business_credit_accounts (
            user_id, credit_limit, available_credit, used_credit, status, kyc_status
        )
        VALUES (
            p_user_id, 0, 0, 0, 'pending', 'pending'
        )
        ON CONFLICT (user_id) DO NOTHING;  -- Don't overwrite if already exists
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.handle_user_profile TO authenticated, anon;


-- ========================
-- PART 5: FIX business_credit_accounts DEFAULTS
-- ========================
-- Change table defaults so any future auto-creation uses 0/pending, not 500000/active

ALTER TABLE public.business_credit_accounts ALTER COLUMN credit_limit SET DEFAULT 0;
ALTER TABLE public.business_credit_accounts ALTER COLUMN available_credit SET DEFAULT 0;
ALTER TABLE public.business_credit_accounts ALTER COLUMN status SET DEFAULT 'pending';

-- Fix any existing untouched 5-lakh accounts (never used = safe to reset)
UPDATE public.business_credit_accounts
SET 
  credit_limit = 0,
  available_credit = 0,
  status = 'pending'
WHERE 
  used_credit = 0 
  AND credit_limit >= 500000;


-- ========================
-- PART 6: VERIFY check_email_exists RPC
-- ========================
-- Used by the app to check if email already exists before signup.
-- Should only check ACTIVE users (not deleted ones).

CREATE OR REPLACE FUNCTION public.check_email_exists(p_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE email = p_email 
          AND status != 'deleted'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_email_exists TO authenticated, anon;


-- ========================
-- DONE! Summary of changes:
-- ========================
-- 1. sync_blocked_emails: Only bans on explicit admin 'blocked', NOT on delete
-- 2. Cleared blocklist of all non-admin-blocked entries
-- 3. handle_user_deletion: Scrambles email/mobile/gst/pan, does NOT add to blocklist
-- 4. handle_new_user: Skips deleted records when checking conflicts
-- 5. handle_user_profile: Creates business credit with 0/pending (NOT 500000/active)
-- 6. Table defaults: credit_limit=0, available_credit=0, status='pending'
-- 7. Reset any existing unused 5-lakh accounts to 0/pending
-- 8. check_email_exists: Ignores deleted users
