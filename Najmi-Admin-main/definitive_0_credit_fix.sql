-- =============================================================================
-- FINAL DEFINITIVE FIX: STOP AUTOMATIC 5 LAKHS CREDIT FOR BUSINESSES
-- Run this script in the Supabase SQL Editor.
-- =============================================================================

-- 1. Ensure the table itself defaults to 0 and 'pending'
ALTER TABLE public.business_credit_accounts 
ALTER COLUMN credit_limit SET DEFAULT 0.00;

ALTER TABLE public.business_credit_accounts 
ALTER COLUMN available_credit SET DEFAULT 0.00;

ALTER TABLE public.business_credit_accounts 
ALTER COLUMN status SET DEFAULT 'pending';

-- 2. Update the RPC function that runs on signup
-- This function is called by the mobile app during registration.
-- We must make sure it inserts 0 for the credit limit.
CREATE OR REPLACE FUNCTION public.handle_user_profile(
    p_user_id uuid,
    p_email text,
    p_name text,
    p_mobile text,
    p_user_type text,
    p_company_name text,
    p_gst_number text,
    p_pan_number text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 1. Upsert the user record
    INSERT INTO public.users (
        id, email, name, mobile, user_type, company_name, 
        gst_number, pan_number, status, role, credit_limit, is_gst_registered
    )
    VALUES (
        p_user_id, p_email, p_name, p_mobile, p_user_type, p_company_name, 
        p_gst_number, p_pan_number, 'active', 'customer', 0, 
        COALESCE(p_gst_number != '', false)
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        mobile = EXCLUDED.mobile,
        user_type = EXCLUDED.user_type,
        company_name = EXCLUDED.company_name,
        gst_number = EXCLUDED.gst_number,
        pan_number = EXCLUDED.pan_number,
        is_gst_registered = EXCLUDED.is_gst_registered,
        updated_at = NOW();

    -- 2. If it's a business/company, create a PENDING credit account with ZERO limit
    IF p_user_type IN ('company', 'business') THEN
        INSERT INTO public.business_credit_accounts (
            user_id, credit_limit, used_credit, available_credit, status
        )
        VALUES (
            p_user_id, 0.00, 0.00, 0.00, 'pending'
        )
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END;
$$;

-- 3. Just in case there's a database trigger on the auth.users table doing this
-- We replace the trigger function too
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.users (id, name, email, mobile, role, status, credit_limit)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'name', ''),
    new.email,
    COALESCE(new.raw_user_meta_data->>'mobile', ''),
    'customer',
    'active',
    0
  )
  ON CONFLICT (id) DO NOTHING;

  -- Create a business credit account ONLY if explicitly a business
  IF new.raw_user_meta_data->>'user_type' IN ('company', 'business') THEN
    INSERT INTO public.business_credit_accounts (user_id, credit_limit, used_credit, available_credit, status)
    VALUES (new.id, 0.00, 0.00, 0.00, 'pending')
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN new;
END;
$$;

-- 4. Fix any existing businesses that mistakenly got 500,000 but haven't used it
UPDATE public.business_credit_accounts
SET 
  credit_limit = 0,
  available_credit = 0,
  status = 'pending',
  updated_at = NOW()
WHERE 
  credit_limit = 500000 
  AND used_credit = 0;
