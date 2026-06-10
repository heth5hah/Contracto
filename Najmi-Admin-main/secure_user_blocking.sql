
-- ENHANCED SECURITY & USER BLOCKING SYSTEM
-- This script ensures blocked/deleted users cannot interact with the system
-- even if they have an active auth session.

-- 1. Ensure the users table has the correct structure and constraints
ALTER TABLE IF EXISTS public.users 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'blocked', 'deleted'));

-- 2. Create a security function to check if a user is valid
-- This function is SECURITY DEFINER to bypass RLS and check the users table directly
CREATE OR REPLACE FUNCTION public.check_user_active(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = user_id AND status = 'active'
    );
$$;

-- 3. Update Users Table RLS Policies
-- Users should only be able to see themselves IF they are active
-- Admins can always see everyone
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
CREATE POLICY "Users can read their own record" ON public.users
    FOR SELECT 
    USING (
        (auth.uid() = id) -- Allow reading own record to check status in app
        OR 
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Users can update their own record" ON public.users;
CREATE POLICY "Users can update their own record" ON public.users
    FOR UPDATE 
    USING (
        (auth.uid() = id AND public.check_user_active(auth.uid()))
        OR 
        public.is_admin(auth.uid())
    );

-- 4. Apply Global Safety to Order and Quotation Tables
-- A blocked user cannot read or create orders/quotations

-- Orders
ALTER TABLE IF EXISTS public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own orders" ON public.orders;
CREATE POLICY "Users can view their own orders" ON public.orders
    FOR SELECT
    USING (
        (user_id = auth.uid() AND public.check_user_active(auth.uid()))
        OR
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Users can create their own orders" ON public.orders;
CREATE POLICY "Users can create their own orders" ON public.orders
    FOR INSERT
    WITH CHECK (
        (user_id = auth.uid() AND public.check_user_active(auth.uid()))
        OR
        public.is_admin(auth.uid())
    );

-- Quotations
ALTER TABLE IF EXISTS public.quotations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own quotations" ON public.quotations;
CREATE POLICY "Users can view their own quotations" ON public.quotations
    FOR SELECT
    USING (
        (user_id = auth.uid() AND public.check_user_active(auth.uid()))
        OR
        public.is_admin(auth.uid())
    );

-- 5. Prevent Re-registration of Blocked Emails
-- We use a trigger that prevents inserting a new user if their email was previously blocked
-- First, we need a way to track "purged" or "blocked" emails if we delete the record
CREATE TABLE IF NOT EXISTS public.blocked_emails (
    email TEXT PRIMARY KEY,
    reason TEXT,
    blocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger to move email to blocklist when a user is blocked or deleted
CREATE OR REPLACE FUNCTION public.sync_blocked_emails()
RETURNS TRIGGER AS $$
BEGIN
    -- If status changed to blocked or deleted, add to blocklist
    IF (TG_OP = 'UPDATE' AND (NEW.status = 'blocked' OR NEW.status = 'deleted')) THEN
        INSERT INTO public.blocked_emails (email, reason)
        VALUES (NEW.email, 'Blocked/Deleted by Admin')
        ON CONFLICT (email) DO NOTHING;
    -- If hard deleted, we assume the admin wanted them gone but we should block re-registration
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO public.blocked_emails (email, reason)
        VALUES (OLD.email, 'Account deleted by Admin')
        ON CONFLICT (email) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_user_block_or_delete ON public.users;
CREATE TRIGGER on_user_block_or_delete
    AFTER UPDATE OR DELETE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.sync_blocked_emails();

-- Function to prevent registration if email is blocked
CREATE OR REPLACE FUNCTION public.check_email_not_blocked()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.blocked_emails WHERE email = NEW.email) THEN
        RAISE EXCEPTION 'This email address is restricted by the administrator.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS before_user_registration ON public.users;
CREATE TRIGGER before_user_registration
    BEFORE INSERT ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.check_email_not_blocked();

-- Give Admin permissions to manage blocklist
GRANT ALL ON public.blocked_emails TO authenticated;
