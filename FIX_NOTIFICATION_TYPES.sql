-- 1. Disable the constraint temporarily (or just drop it as we plan to replace it)
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- 2. Clean up existing data to match the allowed types
-- Convert 'quote_received' to 'quotation'
UPDATE public.notifications 
SET type = 'quotation' 
WHERE type = 'quote_received';

-- Convert 'order_update' to 'order'
UPDATE public.notifications 
SET type = 'order' 
WHERE type = 'order_update';

-- Convert any other unknown types to 'other' to be safe
UPDATE public.notifications 
SET type = 'other' 
WHERE type NOT IN ('order', 'quotation', 'return', 'refund', 'payment', 'system', 'enquiry', 'other');

-- 3. Now apply the new constraint
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN ('order', 'quotation', 'return', 'refund', 'payment', 'system', 'enquiry', 'other'));

-- 4. Re-create the trigger for enquiries (Safe to run even if already exists)
CREATE OR REPLACE FUNCTION notify_user_enquiry_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status IN ('resolved', 'closed', 'contacted') THEN
      PERFORM create_notification(
        'admin',
        'user',
        NEW.user_id,
        CASE NEW.status
          WHEN 'resolved' THEN 'Request Resolved'
          WHEN 'closed' THEN 'Request Closed'
          WHEN 'contacted' THEN 'Request Update'
          ELSE 'Request Status Updated'
        END,
        CASE NEW.status
          WHEN 'resolved' THEN 'Your product request for ' || NEW.product_name || ' has been resolved.'
          WHEN 'closed' THEN 'Your product request for ' || NEW.product_name || ' has been closed.'
          WHEN 'contacted' THEN 'We have an update regarding your request for ' || NEW.product_name || '.'
          ELSE 'Your product request status has been updated.'
        END,
        'enquiry',
        NEW.id,
        jsonb_build_object(
          'enquiry_id', NEW.id,
          'product_name', NEW.product_name,
          'status', NEW.status
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_user_enquiry_status_change ON public.enquiries;
CREATE TRIGGER trigger_notify_user_enquiry_status_change
  AFTER UPDATE ON public.enquiries
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_user_enquiry_status_change();
