-- Quick test: Insert a notification manually to test if the app receives it
-- IMPORTANT: Replace 'YOUR_USER_ID_HERE' with the actual user_id from your users table
-- You can find your user_id by running: SELECT id, email FROM users LIMIT 5;

-- Step 1: Find your user ID (uncomment and run this first)
-- SELECT id, email, name FROM users WHERE email = 'your_email@example.com';

-- Step 2: Insert a test notification (replace the user_id below)
INSERT INTO notifications (user_id, type, message, status, sent_by_admin)
VALUES (
  'YOUR_USER_ID_HERE',  -- Replace with actual user ID
  'quote_received',
  'This is a test notification from SQL',
  'unread',
  true
);

-- Step 3: Check if it was inserted
SELECT id, user_id, type, message, created_at 
FROM notifications 
ORDER BY created_at DESC 
LIMIT 1;
