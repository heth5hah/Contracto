-- =====================================================
-- DIAGNOSTIC: Run this FIRST to see the actual table structure
-- Copy the output and paste it back to me
-- =====================================================

-- 1. Check notifications table columns in exact order
SELECT 
  ordinal_position,
  column_name, 
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'notifications'
ORDER BY ordinal_position;

-- 2. Check all create_notification functions
SELECT 
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'create_notification';

-- 3. Check triggers on notifications table
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'notifications';
