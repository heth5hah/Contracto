-- =========================================================================
-- FIX REGISTRATION: Run this ENTIRE script in Supabase SQL Editor
-- =========================================================================

-- STEP 1: Clean up orphaned public.users records that block new registrations
-- These are records where the auth.users entry was deleted but public.users remains
UPDATE public.users pu
SET 
    email = pu.email || '_deleted_' || gen_random_uuid()::text,
    mobile = pu.mobile || '_del_' || gen_random_uuid()::text,
    gst_number = CASE WHEN pu.gst_number IS NOT NULL THEN pu.gst_number || '_del_' || gen_random_uuid()::text ELSE NULL END,
    pan = CASE WHEN pu.pan IS NOT NULL THEN pu.pan || '_del_' || gen_random_uuid()::text ELSE NULL END,
    status = 'deleted'
WHERE NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = pu.id)
  AND pu.status != 'deleted';

-- Also scramble deleted records that weren't scrambled yet
UPDATE public.users pu
SET 
    mobile = pu.mobile || '_del_' || gen_random_uuid()::text
WHERE pu.status = 'deleted'
  AND pu.mobile NOT LIKE '%_del_%';

UPDATE public.users pu
SET 
    email = pu.email || '_deleted_' || gen_random_uuid()::text
WHERE pu.status = 'deleted'
  AND pu.email NOT LIKE '%_deleted_%';

-- STEP 2: Clear blocked_emails (except admin-blocked)
DELETE FROM public.blocked_emails 
WHERE reason IS DISTINCT FROM 'Blocked by Admin';

-- STEP 3: Recreate handle_new_user trigger function
-- This fires AFTER INSERT on auth.users to auto-create public.users record
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Skip if email is explicitly blocked by admin
  IF EXISTS (SELECT 1 FROM public.blocked_emails WHERE email = new.email) THEN
    RAISE LOG 'handle_new_user: Skipping blocked email %', new.email;
    RETURN new;
  END IF;

  -- Check for active email conflict
  IF EXISTS (SELECT 1 FROM public.users WHERE email = new.email AND status != 'deleted') THEN
    RAISE LOG 'handle_new_user: Email % already exists (active), skipping', new.email;
    RETURN new;
  END IF;

  -- Check for active mobile conflict  
  IF (new.raw_user_meta_data->>'mobile') IS NOT NULL 
     AND (new.raw_user_meta_data->>'mobile') != ''
     AND EXISTS (SELECT 1 FROM public.users WHERE mobile = new.raw_user_meta_data->>'mobile' AND status != 'deleted') THEN
    RAISE LOG 'handle_new_user: Mobile % already exists (active), skipping', new.raw_user_meta_data->>'mobile';
    RETURN new;
  END IF;

  -- Check for active GST conflict
  IF (new.raw_user_meta_data->>'gst_number') IS NOT NULL 
     AND (new.raw_user_meta_data->>'gst_number') != ''
     AND EXISTS (SELECT 1 FROM public.users WHERE gst_number = new.raw_user_meta_data->>'gst_number' AND status != 'deleted') THEN
    RAISE LOG 'handle_new_user: GST % already exists, skipping', new.raw_user_meta_data->>'gst_number';
    RETURN new;
  END IF;

  -- All checks passed, insert the user
  BEGIN
    INSERT INTO public.users (
      id, email, name, mobile, user_type, company_name, gst_number, pan_number, 
      is_gst_registered, credit_limit, status, role, created_at
    )
    VALUES (
      new.id,
      new.email,
      COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
      COALESCE(NULLIF(new.raw_user_meta_data->>'mobile', ''), 'pending_' || new.id::text),
      COALESCE(new.raw_user_meta_data->>'user_type', 'individual'),
      new.raw_user_meta_data->>'company_name',
      new.raw_user_meta_data->>'gst_number',
      new.raw_user_meta_data->>'pan_number',
      (CASE WHEN (new.raw_user_meta_data->>'gst_number') IS NOT NULL 
            AND (new.raw_user_meta_data->>'gst_number') <> '' THEN true ELSE false END),
      0,
      'active',
      'customer',
      NOW()
    );
    RAISE LOG 'handle_new_user: Successfully inserted user % (%)', new.id, new.email;
  EXCEPTION WHEN unique_violation THEN
    RAISE LOG 'handle_new_user: Unique violation for user % (%), skipping insert', new.id, new.email;
  END;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: Ensure the trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- STEP 5: Recreate handle_user_profile RPC (used by the app as backup)
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
    INSERT INTO public.users (
        id, email, name, mobile, user_type, company_name, gst_number, pan_number, 
        is_gst_registered, credit_limit, status, role
    )
    VALUES (
        p_user_id, p_email, p_name, 
        COALESCE(NULLIF(p_mobile, ''), 'pending_' || p_user_id::text),
        p_user_type, p_company_name, 
        NULLIF(p_gst_number, ''), NULLIF(p_pan_number, ''),
        (p_gst_number IS NOT NULL AND p_gst_number <> ''),
        0, 'active', 'customer'
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        mobile = CASE 
            WHEN users.mobile LIKE 'pending_%' THEN EXCLUDED.mobile 
            ELSE COALESCE(NULLIF(EXCLUDED.mobile, ''), users.mobile) 
        END,
        user_type = EXCLUDED.user_type,
        company_name = EXCLUDED.company_name,
        gst_number = COALESCE(EXCLUDED.gst_number, users.gst_number),
        pan_number = COALESCE(EXCLUDED.pan_number, users.pan_number)
    WHERE users.status = 'active';

    -- For company users, create pending credit account
    IF p_user_type = 'company' THEN
        INSERT INTO public.business_credit_accounts (
            user_id, credit_limit, available_credit, used_credit, status, kyc_status
        )
        VALUES (p_user_id, 0, 0, 0, 'pending', 'pending')
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.handle_user_profile TO authenticated, anon;

-- STEP 6: Ensure check_email_exists RPC exists
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

-- STEP 7: Ensure RLS allows authenticated users to insert their own record
-- (This is critical — without it, the app's direct insert fallback fails)
DO $$
BEGIN
  -- Enable RLS if not already
  ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
  
  -- Drop and recreate insert policy for users to insert their own record
  DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
  CREATE POLICY "Users can insert own record" ON public.users
    FOR INSERT
    WITH CHECK (auth.uid() = id);
    
  -- Ensure users can read their own record
  DROP POLICY IF EXISTS "Users can read own record" ON public.users;
  CREATE POLICY "Users can read own record" ON public.users
    FOR SELECT
    USING (auth.uid() = id);

  -- Ensure users can update their own record
  DROP POLICY IF EXISTS "Users can update own record" ON public.users;
  CREATE POLICY "Users can update own record" ON public.users
    FOR UPDATE
    USING (auth.uid() = id);
    
  -- Allow anon to read for email/mobile checks during registration
  DROP POLICY IF EXISTS "Anon can check users" ON public.users;
  CREATE POLICY "Anon can check users" ON public.users
    FOR SELECT
    USING (true);

EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'RLS policy setup warning: %', SQLERRM;
END;
$$;

-- STEP 8: Verify everything is in place
DO $$
DECLARE
  trigger_exists boolean;
  rpc_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created'
  ) INTO trigger_exists;
  
  SELECT EXISTS(
    SELECT 1 FROM pg_proc WHERE proname = 'handle_user_profile'
  ) INTO rpc_exists;
  
  RAISE NOTICE '=== VERIFICATION ===';
  RAISE NOTICE 'on_auth_user_created trigger exists: %', trigger_exists;
  RAISE NOTICE 'handle_user_profile RPC exists: %', rpc_exists;
  RAISE NOTICE 'Orphaned user count: %', (
    SELECT count(*) FROM public.users pu 
    WHERE NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = pu.id)
    AND pu.status != 'deleted'
  );
  RAISE NOTICE 'Blocked emails count: %', (SELECT count(*) FROM public.blocked_emails);
  RAISE NOTICE '=== DONE ===';
END;
$$;
