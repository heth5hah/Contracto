-- FIX FOR BUSINESS ACCOUNT CREATION ISSUES
-- Run this script in the Supabase SQL Editor

-- 1. Create a function that runs when a new user signs up via Auth
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
    role,
    status,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'mobile',
    COALESCE(new.raw_user_meta_data->>'user_type', 'individual'), -- Default to individual
    new.raw_user_meta_data->>'company_name',
    new.raw_user_meta_data->>'gst_number',
    new.raw_user_meta_data->>'pan_number', -- Note: code sends 'pan_number'
    'customer', -- Default role
    'active',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    -- If user already exists, duplicate update to ensure fields are fresh
    user_type = EXCLUDED.user_type,
    company_name = EXCLUDED.company_name,
    gst_number = EXCLUDED.gst_number,
    pan_number = EXCLUDED.pan_number;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create the trigger (or replace if exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Notify success
DO $$
BEGIN
    RAISE NOTICE 'Trigger setup complete. New users will now be automatically added to public.users table.';
END $$;
