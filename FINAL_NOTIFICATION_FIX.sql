-- =====================================================
-- FINAL FIX: Matches actual 16-column table structure
-- Run this entire file in Supabase SQL Editor
-- =====================================================

-- Step 1: Check the type constraint values first
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'public.notifications'::regclass 
AND conname LIKE '%type%';

-- Step 2: Drop existing function
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text, text, text, uuid, jsonb);

-- Step 3: Create function matching ACTUAL table structure
CREATE OR REPLACE FUNCTION public.create_notification(
  p_source text,
  p_target text,
  p_user_id uuid,
  p_title text,
  p_message text,
  p_type text,
  p_reference_id uuid,
  p_metadata jsonb
)
RETURNS uuid AS $$
DECLARE
  v_notification_id uuid;
BEGIN
  INSERT INTO public.notifications (
    user_id,
    type,
    message,
    status,
    sender_id,
    sent_by_admin,
    source,
    target,
    reference_id,
    is_read,
    sound_played,
    metadata,
    title
  ) VALUES (
    p_user_id,
    p_type,
    p_message,
    'unread',  -- status column
    NULL,      -- sender_id
    CASE WHEN p_source = 'admin' THEN true ELSE false END,  -- sent_by_admin
    p_source,
    p_target,
    p_reference_id,
    false,     -- is_read
    false,     -- sound_played
    p_metadata,
    p_title
  )
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Grant permissions
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO service_role;

-- Step 5: Recreate order trigger
CREATE OR REPLACE FUNCTION notify_admin_new_order()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.create_notification(
    'app'::text,
    'admin'::text,
    NULL::uuid,
    'New Order Received'::text,
    ('Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been placed by ' || COALESCE(NEW.customer_name, 'Customer'))::text,
    'order'::text,
    NEW.id::uuid,
    jsonb_build_object(
      'order_id', NEW.id,
      'customer_name', NEW.customer_name,
      'total_amount', NEW.total_amount,
      'order_status', NEW.order_status
    )::jsonb
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS trigger_notify_admin_new_order ON public.orders;
CREATE TRIGGER trigger_notify_admin_new_order
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_order();

SELECT 'Fix applied! Try placing an order now.' as status;
