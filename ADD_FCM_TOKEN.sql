-- Add FCM Token column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS fcm_token text;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token);

-- Update RLS policies to allow users to update their own token
CREATE POLICY "Users can update their own fcm_token" ON public.users
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
