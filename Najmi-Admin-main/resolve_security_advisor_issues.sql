-- SUPABASE SECURITY ADVISOR RESOLUTION SCRIPT
-- Run this script in the Supabase SQL Editor to resolve all security errors

-- =========================================================================
-- PART 1: Enable Row Level Security (RLS) on Tables
-- =========================================================================
ALTER TABLE IF EXISTS public.business_credit_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.credit ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.products_backup ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.blocked_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.schema_migrations ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- PART 2: Create Proper Row Level Security (RLS) Policies
-- =========================================================================

-- Policies for public.credit
DROP POLICY IF EXISTS "Admins can manage all credit info" ON public.credit;
CREATE POLICY "Admins can manage all credit info" ON public.credit
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can view their own credit info" ON public.credit;
CREATE POLICY "Users can view their own credit info" ON public.credit
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Policies for public.invoices
DROP POLICY IF EXISTS "Admins can manage all invoices" ON public.invoices;
CREATE POLICY "Admins can manage all invoices" ON public.invoices
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can view their own invoices" ON public.invoices;
CREATE POLICY "Users can view their own invoices" ON public.invoices
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Policies for public.blocked_emails
DROP POLICY IF EXISTS "Admins can manage blocked_emails" ON public.blocked_emails;
CREATE POLICY "Admins can manage blocked_emails" ON public.blocked_emails
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Policies for public.products_backup (Only admin accessible)
DROP POLICY IF EXISTS "Admins can manage products_backup" ON public.products_backup;
CREATE POLICY "Admins can manage products_backup" ON public.products_backup
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Policies for public.schema_migrations (Only admin readable)
DROP POLICY IF EXISTS "Admins can view schema_migrations" ON public.schema_migrations;
CREATE POLICY "Admins can view schema_migrations" ON public.schema_migrations
    FOR SELECT TO authenticated USING (public.is_admin());

-- =========================================================================
-- PART 3: Convert Security Definer Views to Security Invoker
-- =========================================================================
-- Security Invoker views check permissions of the invoking user, respecting RLS of underlying tables.
ALTER VIEW IF EXISTS public.products_with_brands SET (security_invoker = true);
ALTER VIEW IF EXISTS public.categories_with_counts SET (security_invoker = true);
ALTER VIEW IF EXISTS public.brands_with_product_counts SET (security_invoker = true);
ALTER VIEW IF EXISTS public.returns_with_user_type SET (security_invoker = true);

-- =========================================================================
-- PART 4: Ensure Trigger Functions are SECURITY DEFINER to Avoid RLS Bugs
-- =========================================================================
-- Redefine create_business_credit_account as SECURITY DEFINER so that
-- business credit accounts can be automatically provisioned during user registration.
CREATE OR REPLACE FUNCTION public.create_business_credit_account()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_type = 'company' THEN
        INSERT INTO public.business_credit_accounts (user_id, credit_limit, available_credit, used_credit, status, kyc_status)
        VALUES (NEW.id, 0.00, 0.00, 0.00, 'pending', 'pending')
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Print success confirmation
SELECT 'SUCCESS: All Security Advisor issues and trigger privileges resolved successfully!' AS result;
