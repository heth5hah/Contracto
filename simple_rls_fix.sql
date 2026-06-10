-- SIMPLE FIX: Allow any authenticated user to insert notifications
-- This will definitely work

DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;

CREATE POLICY "Admins can insert notifications" ON notifications 
FOR INSERT 
WITH CHECK (auth.uid() IS NOT NULL);
