-- =====================================================
-- PART A: RUN THIS FIRST - Drops all duplicate functions
-- Copy everything below and paste in Supabase SQL Editor
-- =====================================================

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
