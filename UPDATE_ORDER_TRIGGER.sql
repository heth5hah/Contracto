CREATE OR REPLACE FUNCTION notify_user_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify on status changes (not initial insert)
  IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
    PERFORM create_notification(
      'admin',
      'user',
      NEW.user_id,
      CASE NEW.order_status
        WHEN 'confirmed' THEN 'Order Confirmed'
        WHEN 'processing' THEN 'Order Processing'
        WHEN 'shipped' THEN 'Order Shipped'
        WHEN 'in_transport' THEN 'Order In Transport'
        WHEN 'out_for_delivery' THEN 'Out for Delivery'
        WHEN 'delivered' THEN 'Order Delivered'
        WHEN 'cancelled' THEN 'Order Cancelled'
        WHEN 'returned' THEN 'Order Returned'
        ELSE 'Order Status Updated'
      END,
      CASE NEW.order_status
        WHEN 'confirmed' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been confirmed'
        WHEN 'processing' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is being processed'
        WHEN 'shipped' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been shipped'
        WHEN 'in_transport' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is now in transport'
        WHEN 'out_for_delivery' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is out for delivery'
        WHEN 'delivered' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been delivered'
        WHEN 'cancelled' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been cancelled'
        WHEN 'returned' THEN 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been returned'
        ELSE 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' status is now ' || REPLACE(NEW.order_status, '_', ' ')
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

-- Dropping trigger is not strictly necessary as CREATE OR REPLACE FUNCTION handles the function update, 
-- but ensuring the trigger definition is correct is good practice.
-- The trigger definition itself hasn't changed, just the function logic.
