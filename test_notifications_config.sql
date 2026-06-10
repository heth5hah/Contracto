-- Test script to verify notifications table and realtime configuration
-- Run this in Supabase SQL Editor to check if everything is configured correctly

-- 1. Check if notifications table exists and show its structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- 2. Check if RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'notifications';

-- 3. Check existing RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'notifications';

-- 4. Check if table is in realtime publication
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'notifications';

-- 5. Insert a test notification (replace USER_ID with actual user ID)
-- INSERT INTO notifications (user_id, type, message, status)
-- VALUES ('YOUR_USER_ID_HERE', 'quote_received', 'Test notification', 'unread');

-- 6. View recent notifications
SELECT id, user_id, type, message, status, created_at
FROM notifications
ORDER BY created_at DESC
LIMIT 5;
