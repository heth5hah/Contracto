-- Add DELETE policies for quote_requests table
-- This allows users to delete their own quote requests

-- Drop existing DELETE policies if they exist
DROP POLICY IF EXISTS "Users can delete their own quote requests" ON public.quote_requests;
DROP POLICY IF EXISTS "Admins can delete all quote requests" ON public.quote_requests;

-- Create policy for users to delete their own quote requests
CREATE POLICY "Users can delete their own quote requests" ON public.quote_requests
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.email = auth.jwt() ->> 'email'
            AND users.id = quote_requests.user_id
        )
    );

-- Create policy for admins to delete all quote requests
CREATE POLICY "Admins can delete all quote requests" ON public.quote_requests
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.email = auth.jwt() ->> 'email'
            AND users.role = 'admin'
        )
    );

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'DELETE policies for quote_requests table created successfully!';
END $$;

