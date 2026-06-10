-- This script will insert a test notification for the most recent user
-- Run this in Supabase SQL Editor after the mobile app is running

-- Insert a test notification for the most recently created user
INSERT INTO notifications (user_id, type, message, status, sent_by_admin)
SELECT 
  id as user_id,
  'quote_received' as type,
  'TEST: Your quotation is ready! If you see this as a popup, notifications are working!' as message,
  'unread' as status,
  true as sent_by_admin
FROM users
WHERE role = 'customer'
ORDER BY created_at DESC
LIMIT 1;

-- Show what was inserted
SELECT 
  n.id,
  n.user_id,
  u.email as user_email,
  u.name as user_name,
  n.type,
  n.message,
  n.created_at
FROM notifications n
JOIN users u ON n.user_id = u.id
ORDER BY n.created_at DESC
LIMIT 1;
