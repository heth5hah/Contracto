-- =====================================================
-- DISABLE ORDER STATUS CHANGE NOTIFICATION TRIGGER
-- Run this in Supabase SQL Editor
-- =====================================================

-- Disable the order status change notification trigger
DROP TRIGGER IF EXISTS trigger_notify_user_order_status_change ON public.orders;

-- Also disable other notification triggers that might cause issues
DROP TRIGGER IF EXISTS trigger_notify_admin_new_quotation ON public.quote_requests;
DROP TRIGGER IF EXISTS trigger_notify_user_quotation_status_change ON public.quote_requests;
DROP TRIGGER IF EXISTS trigger_notify_admin_new_return ON public.returns;
DROP TRIGGER IF EXISTS trigger_notify_user_return_status_change ON public.returns;

-- Verify all notification triggers are removed
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name LIKE '%notify%';

-- If query returns 0 rows, all notification triggers are disabled
SELECT 'All notification triggers disabled!' as status;
