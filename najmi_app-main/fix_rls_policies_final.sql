-- Fix RLS policies to allow users to see their quote responses
-- This will resolve the blank quote details screen issue

-- First, check current policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('quotes', 'quote_items') 
ORDER BY tablename, policyname;

-- Drop existing problematic policies if they exist
DROP POLICY IF EXISTS "Users can view quotes for their requests" ON public.quotes;
DROP POLICY IF EXISTS "Users can view quote items for their quotes" ON public.quote_items;

-- Create working policies for quotes table
-- This policy allows users to see quotes for their quote requests
CREATE POLICY "Users can view quotes for their requests" ON public.quotes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quote_requests qr
            WHERE qr.id = quote_request_id 
            AND qr.user_id = auth.uid()
        )
    );

-- Create policy for quote_items table  
CREATE POLICY "Users can view quote items for their quotes" ON public.quote_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quotes q
            JOIN public.quote_requests qr ON q.quote_request_id = qr.id
            WHERE q.id = quote_id 
            AND qr.user_id = auth.uid()
        )
    );

-- Alternative email-based policies (use if the above doesn't work)
-- Uncomment these if the auth.uid() approach fails:

/*
-- Drop the policies created above if they don't work
DROP POLICY IF EXISTS "Users can view quotes for their requests" ON public.quotes;
DROP POLICY IF EXISTS "Users can view quote items for their quotes" ON public.quote_items;

-- Create email-based policies
CREATE POLICY "Users can view quotes for their requests" ON public.quotes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quote_requests qr
            JOIN public.users u ON qr.user_id = u.id
            WHERE qr.id = quote_request_id 
            AND u.email = auth.email()
        )
    );

CREATE POLICY "Users can view quote items for their quotes" ON public.quote_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quotes q
            JOIN public.quote_requests qr ON q.quote_request_id = qr.id
            JOIN public.users u ON qr.user_id = u.id
            WHERE q.id = quote_id 
            AND u.email = auth.email()
        )
    );
*/

-- Verify the policies are created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('quotes', 'quote_items') 
ORDER BY tablename, policyname;

-- Test query to verify access (replace USER_ID with actual user ID)
-- SELECT q.*, qi.* FROM quotes q 
-- LEFT JOIN quote_items qi ON q.id = qi.quote_id
-- JOIN quote_requests qr ON q.quote_request_id = qr.id
-- WHERE qr.user_id = 'USER_ID_HERE';

COMMENT ON POLICY "Users can view quotes for their requests" ON public.quotes IS 'Allows users to see quotes generated for their quote requests';
COMMENT ON POLICY "Users can view quote items for their quotes" ON public.quote_items IS 'Allows users to see quote items for their quotes';

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'RLS policies updated successfully!';
    RAISE NOTICE 'Users should now be able to see their quote responses with pricing details.';
END $$;
