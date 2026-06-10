-- =====================================================
-- PART B: RUN THIS AFTER PART A - Creates the function
-- Copy everything below and paste in Supabase SQL Editor
-- =====================================================

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

GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO service_role;
