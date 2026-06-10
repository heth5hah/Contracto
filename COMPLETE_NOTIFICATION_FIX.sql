-- =====================================================
-- COMPLETE FIX: Run this entire file in Supabase SQL Editor
-- This fixes the notifications_type_check constraint error
-- =====================================================

-- Step 1: Drop and recreate the create_notification function
DROP FUNCTION IF EXISTS public.create_notification(text, text, uuid, text, text, text, uuid, jsonb);

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
    source,
    target,
    user_id,
    title,
    message,
    type,
    reference_id,
    metadata
  ) VALUES (
    p_source,
    p_target,
    p_user_id,
    p_title,
    p_message,
    p_type,
    p_reference_id,
    p_metadata
  )
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, uuid, text, text, text, uuid, jsonb) TO service_role;

-- Step 2: Recreate ALL trigger functions with explicit types

-- 2a: New Order trigger
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

-- 2b: Order status change trigger
CREATE OR REPLACE FUNCTION notify_user_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
    PERFORM public.create_notification(
      'admin'::text,
      'user'::text,
      NEW.user_id::uuid,
      (CASE NEW.order_status
        WHEN 'confirmed' THEN 'Order Confirmed'
        WHEN 'processing' THEN 'Order Processing'
        WHEN 'shipped' THEN 'Order Shipped'
        WHEN 'out_for_delivery' THEN 'Out for Delivery'
        WHEN 'delivered' THEN 'Order Delivered'
        WHEN 'cancelled' THEN 'Order Cancelled'
        ELSE 'Order Status Updated'
      END)::text,
      (CASE NEW.order_status
        WHEN 'confirmed' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been confirmed'
        WHEN 'processing' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is being processed'
        WHEN 'shipped' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been shipped'
        WHEN 'out_for_delivery' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is out for delivery'
        WHEN 'delivered' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been delivered'
        WHEN 'cancelled' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been cancelled'
        ELSE 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' status has been updated'
      END)::text,
      'order'::text,
      NEW.id::uuid,
      jsonb_build_object(
        'order_id', NEW.id,
        'order_status', NEW.order_status,
        'total_amount', NEW.total_amount
      )::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2c: New quotation trigger
CREATE OR REPLACE FUNCTION notify_admin_new_quotation()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.create_notification(
    'app'::text,
    'admin'::text,
    NULL::uuid,
    'New Quotation Request'::text,
    ('Quotation request #' || SUBSTRING(NEW.id::text, 1, 8) || ' received')::text,
    'quotation'::text,
    NEW.id::uuid,
    jsonb_build_object(
      'quotation_id', NEW.id,
      'product_name', NEW.product_name,
      'status', NEW.status
    )::jsonb
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2d: Quotation status change trigger
CREATE OR REPLACE FUNCTION notify_user_quotation_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.create_notification(
      'admin'::text,
      'user'::text,
      NEW.user_id::uuid,
      (CASE NEW.status
        WHEN 'approved' THEN 'Quotation Approved'
        WHEN 'rejected' THEN 'Quotation Rejected'
        ELSE 'Quotation Status Updated'
      END)::text,
      (CASE NEW.status
        WHEN 'approved' THEN 'Your quotation request has been approved'
        WHEN 'rejected' THEN 'Your quotation request has been rejected'
        ELSE 'Your quotation request status has been updated'
      END)::text,
      'quotation'::text,
      NEW.id::uuid,
      jsonb_build_object(
        'quotation_id', NEW.id,
        'status', NEW.status
      )::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2e: New return trigger
CREATE OR REPLACE FUNCTION notify_admin_new_return()
RETURNS TRIGGER AS $$
DECLARE
  v_order_id uuid;
  v_customer_name text;
BEGIN
  v_order_id := NEW.order_id;
  
  SELECT customer_name INTO v_customer_name
  FROM public.orders
  WHERE id = v_order_id;
  
  PERFORM public.create_notification(
    'app'::text,
    'admin'::text,
    NULL::uuid,
    'New Return Request'::text,
    ('Return request for Order #' || SUBSTRING(v_order_id::text, 1, 8) || COALESCE(' from ' || v_customer_name, ''))::text,
    'return'::text,
    NEW.id::uuid,
    jsonb_build_object(
      'return_id', NEW.id,
      'order_id', v_order_id,
      'return_status', NEW.return_status,
      'refund_amount', NEW.refund_amount
    )::jsonb
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2f: Return status change trigger
CREATE OR REPLACE FUNCTION notify_user_return_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_order_id uuid;
BEGIN
  v_order_id := NEW.order_id;
  
  IF OLD.return_status IS DISTINCT FROM NEW.return_status THEN
    PERFORM public.create_notification(
      'admin'::text,
      'user'::text,
      NEW.user_id::uuid,
      (CASE NEW.return_status
        WHEN 'approved' THEN 'Return Approved'
        WHEN 'rejected' THEN 'Return Rejected'
        WHEN 'completed' THEN 'Return Completed'
        ELSE 'Return Status Updated'
      END)::text,
      (CASE NEW.return_status
        WHEN 'approved' THEN 'Your return request for Order #' || SUBSTRING(v_order_id::text, 1, 8) || ' has been approved'
        WHEN 'rejected' THEN 'Your return request for Order #' || SUBSTRING(v_order_id::text, 1, 8) || ' has been rejected'
        WHEN 'completed' THEN 'Your return for Order #' || SUBSTRING(v_order_id::text, 1, 8) || ' has been completed'
        ELSE 'Your return request status has been updated'
      END)::text,
      'return'::text,
      NEW.id::uuid,
      jsonb_build_object(
        'return_id', NEW.id,
        'order_id', v_order_id,
        'return_status', NEW.return_status,
        'refund_amount', NEW.refund_amount
      )::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Recreate all triggers
DROP TRIGGER IF EXISTS trigger_notify_admin_new_order ON public.orders;
CREATE TRIGGER trigger_notify_admin_new_order
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_order();

DROP TRIGGER IF EXISTS trigger_notify_user_order_status_change ON public.orders;
CREATE TRIGGER trigger_notify_user_order_status_change
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
  EXECUTE FUNCTION notify_user_order_status_change();

DROP TRIGGER IF EXISTS trigger_notify_admin_new_quotation ON public.quote_requests;
CREATE TRIGGER trigger_notify_admin_new_quotation
  AFTER INSERT ON public.quote_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_quotation();

DROP TRIGGER IF EXISTS trigger_notify_user_quotation_status_change ON public.quote_requests;
CREATE TRIGGER trigger_notify_user_quotation_status_change
  AFTER UPDATE ON public.quote_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_user_quotation_status_change();

-- Only create return triggers if returns table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'returns') THEN
    DROP TRIGGER IF EXISTS trigger_notify_admin_new_return ON public.returns;
    CREATE TRIGGER trigger_notify_admin_new_return
      AFTER INSERT ON public.returns
      FOR EACH ROW
      EXECUTE FUNCTION notify_admin_new_return();
      
    DROP TRIGGER IF EXISTS trigger_notify_user_return_status_change ON public.returns;
    CREATE TRIGGER trigger_notify_user_return_status_change
      AFTER UPDATE ON public.returns
      FOR EACH ROW
      EXECUTE FUNCTION notify_user_return_status_change();
  END IF;
END $$;

-- Done! Test by placing an order
SELECT 'All notification triggers fixed!' as status;
