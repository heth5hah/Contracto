-- Alternative RLS Policy Fix for Notifications
-- This version checks if the user has 'admin' role in the users table

-- 1. Drop existing INSERT policy
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;

-- 2. Create policy that allows users with 'admin' role to insert notifications
CREATE POLICY "Admins can insert notifications" ON notifications 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users 
    WHERE users.id = auth.uid() 
    AND users.role = 'admin'
  )
);

-- 3. Alternative: If the above doesn't work, try this simpler version
-- This allows ANY authenticated user to insert (less secure but will work)
-- DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;
-- CREATE POLICY "Admins can insert notifications" ON notifications 
-- FOR INSERT 
-- WITH CHECK (auth.uid() IS NOT NULL);
