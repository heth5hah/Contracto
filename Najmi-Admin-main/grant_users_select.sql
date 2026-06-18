-- =========================================================================
-- SQL SCRIPT: Grant SELECT privilege on public.users table
-- Run this in your Supabase SQL Editor to resolve the mobile app error
-- without changing any existing policies or breaking other features.
-- =========================================================================

-- Grant SELECT privilege on public.users table toauthenticated and anon roles
GRANT SELECT ON public.users TO authenticated, anon, service_role;

-- Grant USAGE on public schema just in case it was restricted
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;

-- Confirm success
SELECT 'SUCCESS: SELECT privilege granted on public.users table!' AS result;
