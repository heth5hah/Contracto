-- Fix RLS policies for quote_requests table
-- This allows authenticated users to create and read their own quote requests

-- First, disable RLS temporarily to clear existing policies
ALTER TABLE public.quote_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.quote_request_items DISABLE ROW LEVEL SECURITY;

-- Re-enable RLS
ALTER TABLE public.quote_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quote_request_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can create quote requests" ON public.quote_requests;
DROP POLICY IF EXISTS "Users can read their own quote requests" ON public.quote_requests;
DROP POLICY IF EXISTS "Users can update their own quote requests" ON public.quote_requests;
DROP POLICY IF EXISTS "Admins can read all quote requests" ON public.quote_requests;

-- Drop existing policies for quote_request_items if they exist
DROP POLICY IF EXISTS "Users can create quote request items" ON public.quote_request_items;
DROP POLICY IF EXISTS "Users can read their own quote request items" ON public.quote_request_items;
DROP POLICY IF EXISTS "Admins can read all quote request items" ON public.quote_request_items;

-- Create policy for users to create quote requests (allow all authenticated users)
CREATE POLICY "Users can create quote requests" ON public.quote_requests
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Create policy for users to read their own quote requests
CREATE POLICY "Users can read their own quote requests" ON public.quote_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.email = auth.jwt() ->> 'email'
            AND users.id = quote_requests.user_id
        )
    );

-- Create policy for users to update their own quote requests
CREATE POLICY "Users can update their own quote requests" ON public.quote_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.email = auth.jwt() ->> 'email'
            AND users.id = quote_requests.user_id
        )
    );

-- Create policy for admins to read all quote requests
CREATE POLICY "Admins can read all quote requests" ON public.quote_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.email = auth.jwt() ->> 'email'
            AND users.role = 'admin'
        )
    );

-- Create policy for users to create quote request items (allow all authenticated users)
CREATE POLICY "Users can create quote request items" ON public.quote_request_items
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Create policy for users to read their own quote request items
CREATE POLICY "Users can read their own quote request items" ON public.quote_request_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quote_requests qr
            JOIN public.users u ON u.id = qr.user_id
            WHERE u.email = auth.jwt() ->> 'email'
            AND qr.id = quote_request_items.quote_request_id
        )
    );

-- Create policy for admins to read all quote request items
CREATE POLICY "Admins can read all quote request items" ON public.quote_request_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.email = auth.jwt() ->> 'email'
            AND users.role = 'admin'
        )
    );

-- Grant necessary permissions
GRANT ALL ON public.quote_requests TO authenticated;
GRANT ALL ON public.quote_request_items TO authenticated; 
