-- Replace the order status trigger to ensure it ONLY fires when order_status actually changes.
CREATE OR REPLACE FUNCTION public.notify_user_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify on status changes (not initial insert, nor when other columns update)
  IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
    PERFORM create_notification(
      'admin',
      'user',
      NEW.user_id,
      CASE NEW.order_status
        WHEN 'confirmed' THEN 'Order Confirmed'
        WHEN 'processing' THEN 'Order Processing'
        WHEN 'shipped' THEN 'Order Shipped'
        WHEN 'out_for_delivery' THEN 'Out for Delivery'
        WHEN 'delivered' THEN 'Order Delivered'
        WHEN 'cancelled' THEN 'Order Cancelled'
        ELSE 'Order Status Updated'
      END,
      CASE NEW.order_status
        WHEN 'confirmed' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been confirmed'
        WHEN 'processing' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is being processed'
        WHEN 'shipped' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been shipped'
        WHEN 'out_for_delivery' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is out for delivery'
        WHEN 'delivered' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been delivered'
        WHEN 'cancelled' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been cancelled'
        ELSE 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' status has been updated'
      END,
      'order',
      NEW.id,
      jsonb_build_object(
        'order_id', NEW.id,
        'order_status', NEW.order_status,
        'total_amount', NEW.total_amount
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_user_order_status_change ON public.orders;
CREATE TRIGGER trigger_notify_user_order_status_change
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
  EXECUTE FUNCTION notify_user_order_status_change();
