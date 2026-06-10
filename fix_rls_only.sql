-- RLS Policy Fix for Notifications
-- Run this if you got an error about "already member of publication"

-- 1. Ensure RLS is enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 2. Policy: Users can see their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications 
FOR SELECT USING (auth.uid() = user_id);

-- 3. Policy: Any authenticated user can insert notifications (for admin functionality)
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;
CREATE POLICY "Admins can insert notifications" ON notifications 
FOR INSERT TO authenticated
WITH CHECK (true);

-- 4. Policy: Users can update their own notifications (e.g. mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications 
FOR UPDATE USING (auth.uid() = user_id);
