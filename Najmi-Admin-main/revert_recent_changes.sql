-- =========================================================================
-- SQL SCRIPT: Revert recent schema and security changes
-- Run this in your Supabase SQL Editor to restore previous working state.
-- =========================================================================

-- PART 1: Revert table-level RLS changes
ALTER TABLE IF EXISTS public.credit DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.invoices DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.products_backup DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.blocked_emails DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.schema_migrations DISABLE ROW LEVEL SECURITY;

-- PART 2: Drop policies created by the security advisor script
DROP POLICY IF EXISTS "Admins can manage all credit info" ON public.credit;
DROP POLICY IF EXISTS "Users can view their own credit info" ON public.credit;
DROP POLICY IF EXISTS "Admins can manage all invoices" ON public.invoices;
DROP POLICY IF EXISTS "Users can view their own invoices" ON public.invoices;
DROP POLICY IF EXISTS "Admins can manage blocked_emails" ON public.blocked_emails;
DROP POLICY IF EXISTS "Admins can manage products_backup" ON public.products_backup;
DROP POLICY IF EXISTS "Admins can view schema_migrations" ON public.schema_migrations;

-- PART 3: Revert views to security_invoker = false
ALTER VIEW IF EXISTS public.products_with_brands SET (security_invoker = false);
ALTER VIEW IF EXISTS public.categories_with_counts SET (security_invoker = false);
ALTER VIEW IF EXISTS public.brands_with_product_counts SET (security_invoker = false);
ALTER VIEW IF EXISTS public.returns_with_user_type SET (security_invoker = false);

-- PART 4: Revert trigger function create_business_credit_account to plpgsql
CREATE OR REPLACE FUNCTION public.create_business_credit_account()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_type = 'company' THEN
        INSERT INTO public.business_credit_accounts (user_id, credit_limit, available_credit)
        VALUES (NEW.id, 500000.00, 500000.00)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- PART 5: Revert users helper functions to original state
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = user_id AND LOWER(role) = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    RETURN v_role = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 6: Revert users table RLS policies to original V6 registration state
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update their own record" ON public.users;
DROP POLICY IF EXISTS "Admins have full access" ON public.users;
DROP POLICY IF EXISTS "Anyone can browse users" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own record if active" ON public.users;
DROP POLICY IF EXISTS "Admin full access" ON public.users;

CREATE POLICY "Anyone can browse users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert their own record" ON public.users FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own record if active" ON public.users FOR UPDATE TO authenticated USING (auth.uid() = id AND status = 'active') WITH CHECK (auth.uid() = id AND status = 'active');
CREATE POLICY "Admin full access" ON public.users FOR ALL TO authenticated USING (public.is_admin(auth.uid()));

-- PART 7: Output success message
SELECT 'SUCCESS: All recent schema, RLS, and functions have been reverted to their previous state!' AS result;
