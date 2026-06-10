-- Add new types to the check constraint
-- We need to drop the old constraint and add a new one because PostgreSQL doesn't support altering ENUMs inside a check constraint easily without dropping it.
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN ('order', 'quotation', 'return', 'refund', 'payment', 'system', 'enquiry', 'other'));

-- Update create_notification function to support new types if needed (it takes text so it's fine, but good to be aware)

-- ====================================================
-- Trigger: Enquiry Status Changed → Notify User
-- ====================================================
CREATE OR REPLACE FUNCTION notify_user_enquiry_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Only notify for specific status changes that are relevant to the user
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
