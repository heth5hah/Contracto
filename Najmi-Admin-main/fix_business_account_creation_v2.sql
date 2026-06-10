-- FIX FOR BUSINESS ACCOUNT CREATION (V8)
-- Run this script in the Supabase SQL Editor

-- 1. Drop the old trigger and function first to ensure a clean slate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 2. Create the IMPROVED function with all required columns and NULL handling
-- REMOVED: updated_at column
-- UPDATED: Name fallback logic
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (
    id,
    email,
    name,
    mobile,
    user_type,
    company_name,
    gst_number,
    pan_number,
    is_gst_registered,
    credit_limit,
    role,
    status,
    created_at
  )
  VALUES (
    new.id,
    new.email,
    -- Fallback for name: Use metadata, or email prefix if missing
    COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    -- Mobile is required by DB. If missing in metadata, this insert might fail 
    -- unless we provide a dummy, but better to let it fail so app knows data is bad.
    new.raw_user_meta_data->>'mobile',
    COALESCE(new.raw_user_meta_data->>'user_type', 'individual'),
    new.raw_user_meta_data->>'company_name',
    new.raw_user_meta_data->>'gst_number',
    new.raw_user_meta_data->>'pan_number',
    -- Calculate is_gst_registered from gst_number presence
    (CASE WHEN (new.raw_user_meta_data->>'gst_number') IS NOT NULL AND (new.raw_user_meta_data->>'gst_number') <> '' THEN true ELSE false END),
    0.0,                -- Default credit limit
    'customer',         -- Default role
    'active',
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    user_type = EXCLUDED.user_type,
    company_name = EXCLUDED.company_name,
    gst_number = EXCLUDED.gst_number,
    pan_number = EXCLUDED.pan_number,
    is_gst_registered = EXCLUDED.is_gst_registered;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Re-create the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. BACKFILL: Fix the users that failed to create recently
-- UPDATED: Handles NULL name AND NULL mobile AND duplicate GST
INSERT INTO public.users (
    id,
    email,
    name,
    mobile,
    user_type,
    company_name,
    gst_number,
    pan_number,
    is_gst_registered,
    credit_limit,
    role,
    status,
    created_at
)
SELECT 
    au.id,
    au.email,
    -- Fix for NULL names: Use metadata name OR email part before '@'
    COALESCE(au.raw_user_meta_data->>'name', split_part(au.email, '@', 1), 'User'),
    au.raw_user_meta_data->>'mobile',
    COALESCE(au.raw_user_meta_data->>'user_type', 'individual'),
    au.raw_user_meta_data->>'company_name',
    au.raw_user_meta_data->>'gst_number',
    au.raw_user_meta_data->>'pan_number',
    (CASE WHEN (au.raw_user_meta_data->>'gst_number') IS NOT NULL AND (au.raw_user_meta_data->>'gst_number') <> '' THEN true ELSE false END),
    0.0,
    'customer',
    'active',
    COALESCE(au.created_at, NOW())
FROM auth.users au
WHERE NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.id = au.id)
  AND NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.email = au.email)
  -- SKIP users with duplicate mobiles
  AND (
      (au.raw_user_meta_data->>'mobile') IS NULL 
      OR NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.mobile = au.raw_user_meta_data->>'mobile')
  )
  -- SKIP users with duplicate GST numbers
  AND (
      (au.raw_user_meta_data->>'gst_number') IS NULL 
      OR NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.gst_number = au.raw_user_meta_data->>'gst_number')
  )
  -- SKIP users with NULL mobiles
  AND (au.raw_user_meta_data->>'mobile') IS NOT NULL;

-- 5. Notify success
DO $$
BEGIN
    RAISE NOTICE 'V8 Fix applied. Handled duplicate GST numbers.';
END $$;
