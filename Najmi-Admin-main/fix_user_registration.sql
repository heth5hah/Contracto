
-- FINAL FIX FOR USER REGISTRATION AND BLOCKING SYSTEM (V6)
-- This script fixes the "Account not found" error for new users
-- while maintaining strict security for blocked users.

-- 1. Helper Function: Check if a user is an admin
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = user_id AND LOWER(role) = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Define the handle_user_profile RPC
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Automatic Profile Creation Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- SKIP if email is blocked
  IF EXISTS (SELECT 1 FROM public.blocked_emails WHERE email = new.email) THEN
    RETURN new;
  END IF;

  -- Insert into public.users ONLY if no unique conflicts exist
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE mobile = new.raw_user_meta_data->>'mobile' OR email = new.email) THEN
    -- Check for GST/PAN conflicts
    IF (new.raw_user_meta_data->>'gst_number' IS NOT NULL AND EXISTS (SELECT 1 FROM public.users WHERE gst_number = new.raw_user_meta_data->>'gst_number')) THEN
        RETURN new;
    END IF;
    
    IF (new.raw_user_meta_data->>'pan_number' IS NOT NULL AND EXISTS (SELECT 1 FROM public.users WHERE pan_number = new.raw_user_meta_data->>'pan_number')) THEN
        RETURN new;
    END IF;

    INSERT INTO public.users (
      id, email, name, mobile, user_type, company_name, gst_number, pan_number, status, role
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
      'active',
      'customer'
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

-- 4. Fix Users Table RLS Policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can browse users" ON public.users;
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
DROP POLICY IF EXISTS "Admin full access" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own record if active" ON public.users;

CREATE POLICY "Anyone can browse users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert their own record" ON public.users FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own record if active" ON public.users FOR UPDATE TO authenticated USING (auth.uid() = id AND status = 'active') WITH CHECK (auth.uid() = id AND status = 'active');
CREATE POLICY "Admin full access" ON public.users FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

-- 5. Backfill missing users with GLOBAL DUPLICATE AND BLOCKLIST protection
INSERT INTO public.users (id, email, name, mobile, user_type, company_name, gst_number, pan_number, status, role)
SELECT 
    au.id, au.email, 
    COALESCE(au.raw_user_meta_data->>'name', split_part(au.email, '@', 1)),
    COALESCE(au.raw_user_meta_data->>'mobile', ''),
    COALESCE(au.raw_user_meta_data->>'user_type', 'individual'),
    au.raw_user_meta_data->>'company_name',
    au.raw_user_meta_data->>'gst_number',
    au.raw_user_meta_data->>'pan_number',
    'active', 'customer'
FROM auth.users au
WHERE 
    NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.id = au.id) 
    AND
    NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.email = au.email)
    AND
    -- CRITICAL: Skip if Email is in blocklist
    NOT EXISTS (SELECT 1 FROM public.blocked_emails be WHERE be.email = au.email)
    AND
    -- Skip if Mobile exists
    (
      (au.raw_user_meta_data->>'mobile') IS NULL OR 
      NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.mobile = au.raw_user_meta_data->>'mobile')
    )
    AND
    -- Skip if GST exists
    (
      (au.raw_user_meta_data->>'gst_number') IS NULL OR 
      NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.gst_number = au.raw_user_meta_data->>'gst_number')
    )
    AND
    -- Skip if PAN exists
    (
      (au.raw_user_meta_data->>'pan_number') IS NULL OR 
      NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.pan_number = au.raw_user_meta_data->>'pan_number')
    )
ON CONFLICT (id) DO NOTHING;

-- 6. Grant Permissions
GRANT EXECUTE ON FUNCTION public.handle_user_profile TO authenticated, anon;
GRANT ALL ON public.users TO authenticated, anon, service_role;
