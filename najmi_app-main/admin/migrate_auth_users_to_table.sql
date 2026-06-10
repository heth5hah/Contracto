-- Migrate existing Supabase Auth users to the users table
-- This script will create user records for existing authenticated users

-- First, let's see what users exist in auth.users but not in public.users
SELECT 
    au.id,
    au.email,
    au.user_metadata,
    au.created_at as auth_created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
AND au.email IS NOT NULL;

-- Create a function to safely insert users
CREATE OR REPLACE FUNCTION migrate_auth_user(
    auth_user_id UUID,
    user_email TEXT,
    user_metadata JSONB
) RETURNS BOOLEAN AS $$
DECLARE
    user_name TEXT;
    user_mobile TEXT;
    user_pan TEXT;
    user_gst TEXT;
BEGIN
    -- Extract user data from metadata
    user_name := COALESCE(user_metadata->>'name', user_email);
    user_mobile := COALESCE(user_metadata->>'mobile', 'N/A');
    user_pan := user_metadata->>'pan';
    user_gst := user_metadata->>'gst_number';
    
    -- Insert user into public.users table
    INSERT INTO public.users (
        id,
        name,
        email,
        mobile,
        pan,
        gst_number,
        role,
        credit_limit,
        status,
        created_at
    ) VALUES (
        auth_user_id,
        user_name,
        user_email,
        user_mobile,
        user_pan,
        user_gst,
        'customer',
        0.0,
        'active',
        NOW()
    );
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Failed to migrate user %: %', user_email, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Migrate all existing auth users
DO $$
DECLARE
    auth_user RECORD;
    success_count INTEGER := 0;
    total_count INTEGER := 0;
BEGIN
    FOR auth_user IN 
        SELECT 
            au.id,
            au.email,
            au.user_metadata,
            au.created_at
        FROM auth.users au
        LEFT JOIN public.users pu ON au.id = pu.id
        WHERE pu.id IS NULL
        AND au.email IS NOT NULL
    LOOP
        total_count := total_count + 1;
        
        IF migrate_auth_user(
            auth_user.id, 
            auth_user.email, 
            auth_user.user_metadata
        ) THEN
            success_count := success_count + 1;
            RAISE NOTICE 'Successfully migrated user: %', auth_user.email;
        ELSE
            RAISE NOTICE 'Failed to migrate user: %', auth_user.email;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Migration completed: % out of % users migrated successfully', success_count, total_count;
END $$;

-- Verify the migration
SELECT 
    'Total users in auth.users' as source,
    COUNT(*) as count
FROM auth.users
UNION ALL
SELECT 
    'Total users in public.users' as source,
    COUNT(*) as count
FROM public.users
UNION ALL
SELECT 
    'Users with matching IDs' as source,
    COUNT(*) as count
FROM auth.users au
JOIN public.users pu ON au.id = pu.id;

-- Clean up the temporary function
DROP FUNCTION IF EXISTS migrate_auth_user(UUID, TEXT, JSONB);

-- Show final status
DO $$
BEGIN
    RAISE NOTICE 'User migration completed!';
    RAISE NOTICE 'Check the results above to verify all users were migrated.';
END $$;
