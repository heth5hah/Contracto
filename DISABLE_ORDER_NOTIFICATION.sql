-- =====================================================
-- QUICK FIX: Disable notification trigger temporarily
-- This allows orders to be placed while we fix notifications
-- =====================================================

-- Option 1: Disable the trigger (orders will work, no notifications)
DROP TRIGGER IF EXISTS trigger_notify_admin_new_order ON public.orders;

-- Verify trigger is gone
SELECT trigger_name FROM information_schema.triggers 
WHERE event_object_table = 'orders' AND trigger_name LIKE '%notify%';

-- If the query returns NO rows, the trigger is disabled.
-- Try placing an order now!

-- =====================================================
-- LATER: To re-enable notifications, run the fix script
-- =====================================================
