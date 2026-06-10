-- =============================================================================
-- COMPLETE FIX: New business users should get ZERO credit by default
-- The admin must manually activate and set the credit limit.
--
-- Run this ENTIRE script in your Supabase SQL Editor (one shot).
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 0: Fix the CHECK constraint on status column to allow 'pending'
--         Currently it only allows ('active', 'inactive') — we need 'pending'.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.business_credit_accounts 
  DROP CONSTRAINT IF EXISTS business_credit_accounts_status_check;

ALTER TABLE public.business_credit_accounts 
  ADD CONSTRAINT business_credit_accounts_status_check 
  CHECK (status IN ('active', 'inactive', 'pending'));

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 1: Fix table-level defaults so any future INSERT without explicit 
--         values gets 0/pending instead of 500000/active.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.business_credit_accounts ALTER COLUMN credit_limit SET DEFAULT 0.00;
ALTER TABLE public.business_credit_accounts ALTER COLUMN available_credit SET DEFAULT 0.00;
ALTER TABLE public.business_credit_accounts ALTER COLUMN status SET DEFAULT 'pending';

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 2: Fix any existing business accounts that were auto-created with 
--         5,00,000 but never used (used_credit = 0). 
--         This sets them to 0 and pending so admin must approve.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public.business_credit_accounts
SET 
  credit_limit = 0.00,
  available_credit = 0.00,
  status = 'pending'
WHERE 
  used_credit = 0.00 
  AND credit_limit = 500000.00;

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 3: Replace the handle_user_profile RPC function.
--         This is called from the Flutter app on first login.
--         KEY CHANGE: For company users, credit account is created with
--                     credit_limit=0, available_credit=0, status='pending'
-- ─────────────────────────────────────────────────────────────────────────────
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
    -- Upsert user profile
    INSERT INTO public.users (
        id, email, name, mobile, user_type, company_name, gst_number, pan_number, status, role
    )
    VALUES (
        p_user_id, p_email, p_name, p_mobile, p_user_type, p_company_name, p_gst_number, p_pan_number, 'active', 'customer'
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

    -- For company/business users, auto-create a PENDING credit account with ZERO limit
    -- The admin must manually activate it and set the credit limit
    IF p_user_type = 'company' THEN
        INSERT INTO public.business_credit_accounts (
            user_id, credit_limit, available_credit, used_credit, status, kyc_status
        )
        VALUES (
            p_user_id, 0, 0, 0, 'pending', 'pending'
        )
        ON CONFLICT (user_id) DO NOTHING;  -- Don't overwrite if admin already set it up
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.handle_user_profile TO authenticated, anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 4: Replace the handle_new_user trigger function.
--         This fires automatically when a user signs up via Supabase Auth.
--         KEY CHANGE: For company users, credit account is created with ZERO.
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- SKIP if email is blocked
  IF EXISTS (SELECT 1 FROM public.blocked_emails WHERE email = new.email) THEN
    RETURN new;
  END IF;

  -- Insert into public.users ONLY if no unique conflicts exist
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE mobile = new.raw_user_meta_data->>'mobile' OR email = new.email) THEN
    -- Check for GST conflicts
    IF (new.raw_user_meta_data->>'gst_number' IS NOT NULL AND EXISTS (SELECT 1 FROM public.users WHERE gst_number = new.raw_user_meta_data->>'gst_number')) THEN
        RETURN new;
    END IF;
    
    -- Check for PAN conflicts
    IF (new.raw_user_meta_data->>'pan_number' IS NOT NULL AND EXISTS (SELECT 1 FROM public.users WHERE pan_number = new.raw_user_meta_data->>'pan_number')) THEN
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
      (CASE WHEN (new.raw_user_meta_data->>'gst_number') IS NOT NULL AND (new.raw_user_meta_data->>'gst_number') <> '' THEN true ELSE false END),
      0.0,         -- credit_limit = 0 (no free credit line!)
      'active',
      'customer',
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    -- For company users, auto-create a PENDING credit account with ZERO limit
    IF COALESCE(new.raw_user_meta_data->>'user_type', 'individual') = 'company' THEN
      INSERT INTO public.business_credit_accounts (
        user_id, credit_limit, available_credit, used_credit, status, kyc_status
      )
      VALUES (
        new.id, 0, 0, 0, 'pending', 'pending'
      )
      ON CONFLICT (user_id) DO NOTHING;
    END IF;
  END IF;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 5: Drop any OTHER triggers that might auto-create credit accounts
--         with 500000. Check for triggers on the users table.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT tgname, tgrelid::regclass, tgtype, proname
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'public.users'::regclass
  AND NOT tgisinternal;

-- ─────────────────────────────────────────────────────────────────────────────
-- PART 6: Also check for triggers on business_credit_accounts itself
-- ─────────────────────────────────────────────────────────────────────────────
SELECT tgname, tgrelid::regclass, tgtype, proname
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'public.business_credit_accounts'::regclass
  AND NOT tgisinternal;

-- ─────────────────────────────────────────────────────────────────────────────
-- DONE! Verify the fix:
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '✅ Fix applied successfully!';
    RAISE NOTICE '   → CHECK constraint updated to allow: active, inactive, pending';
    RAISE NOTICE '   → Table defaults: credit_limit=0, available_credit=0, status=pending';
    RAISE NOTICE '   → handle_user_profile RPC: creates credit with 0/pending';
    RAISE NOTICE '   → handle_new_user trigger: creates credit with 0/pending';
    RAISE NOTICE '   → Existing unused 5L accounts reset to 0/pending';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  CHECK the trigger query results above (PART 5 & 6).';
    RAISE NOTICE '   If you see any trigger with "500000" in its function, drop it.';
END $$;
