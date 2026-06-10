-- Check and fix the order notification trigger
-- Run this in Supabase SQL Editor

-- Step 1: Check if trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'orders';

-- Step 2: Recreate the trigger function with correct function call
CREATE OR REPLACE FUNCTION notify_admin_new_order()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.create_notification(
    'app'::text,           -- p_source
    'admin'::text,         -- p_target
    NULL::uuid,            -- p_user_id
    'New Order Received'::text,  -- p_title
    ('Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been placed by ' || COALESCE(NEW.customer_name, 'Customer'))::text,  -- p_message
    'order'::text,         -- p_type
    NEW.id,                -- p_reference_id
    jsonb_build_object(
      'order_id', NEW.id,
      'customer_name', NEW.customer_name,
      'total_amount', NEW.total_amount,
      'order_status', NEW.order_status
    )                      -- p_metadata
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Recreate the trigger
DROP TRIGGER IF EXISTS trigger_notify_admin_new_order ON public.orders;
CREATE TRIGGER trigger_notify_admin_new_order
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_order();
