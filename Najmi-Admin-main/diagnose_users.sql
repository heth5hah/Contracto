-- DIAGNOSTIC SCRIPT
-- Run this in Supabase SQL Editor to see what happened with the last 5 signups

SELECT 
    au.id,
    au.email,
    au.created_at as auth_created_at,
    au.raw_user_meta_data, -- THIS SHOWS WHAT THE APP SENT
    pu.id as public_id,
    pu.user_type as public_user_type,
    pu.company_name as public_company_name,
    pu.role as public_role
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
ORDER BY au.created_at DESC
LIMIT 5;
