-- Fix create_notification function ambiguity error
-- Run EACH STEP separately in Supabase SQL Editor

-- ================================================================
-- STEP 1: First, list all existing function signatures
-- Run this to see what functions exist
-- ================================================================
SELECT 
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  'DROP FUNCTION IF EXISTS public.create_notification(' || pg_get_function_identity_arguments(p.oid) || ');' AS drop_statement
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'create_notification';

-- ================================================================
-- STEP 2: Run these DROP statements one by one
-- (Copy from the output above or try these common ones)
-- ================================================================
DROP FUNCTION IF EXISTS public.create_notification();
DROP FUNCTION IF EXISTS public.create_notification(text);
DROP FUNCTION IF EXISTS public.create_notification(text, text);
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid);
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text);
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text, text);
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text, text, text);
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text, text, text, uuid, jsonb);
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text, text, text, uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.create_notification(text, text, text, text, text, text, uuid, jsonb);
DROP FUNCTION IF EXISTS public.create_notification(text, text, text, text, text, text, uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.create_notification(text, text, text, text, text, text, text, uuid, jsonb);

-- ================================================================
-- STEP 3: Verify all functions are dropped (should return 0 rows)
-- ================================================================
SELECT count(*) as remaining_functions
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'create_notification';

-- ================================================================
-- STEP 4: Recreate the function with the correct signature
-- ================================================================
CREATE OR REPLACE FUNCTION public.create_notification(
  p_source text,
  p_target text,
  p_user_id uuid DEFAULT NULL,
  p_title text DEFAULT '',
  p_message text DEFAULT '',
  p_type text DEFAULT 'other',
  p_reference_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_notification_id uuid;
BEGIN
  INSERT INTO public.notifications (
    source,
    target,
    user_id,
    title,
    message,
    type,
    reference_id,
    metadata
  ) VALUES (
    p_source::text,
    p_target::text,
    p_user_id,
    p_title::text,
    p_message::text,
    p_type::text,
    p_reference_id,
    p_metadata
  )
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- STEP 5: Grant execute permission
-- ================================================================
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO service_role;

-- ================================================================
-- STEP 6: Verify only 1 function exists now
-- ================================================================
SELECT 
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'create_notification';
