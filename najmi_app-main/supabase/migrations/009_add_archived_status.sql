-- Add 'archived' to the status check constraint for quote_requests table
-- We are keeping 'cancelled' for backward compatibility or if used elsewhere, 
-- but strictly adding 'archived' as requested.

ALTER TABLE public.quote_requests 
DROP CONSTRAINT IF EXISTS quote_requests_status_check;

ALTER TABLE public.quote_requests 
ADD CONSTRAINT quote_requests_status_check 
CHECK (status IN ('pending', 'quoted', 'accepted', 'rejected', 'cancelled', 'archived', 'active'));

-- Also update the constraint for the quotes table if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'quotes') THEN
        ALTER TABLE public.quotes 
        DROP CONSTRAINT IF EXISTS quotes_status_check;

        ALTER TABLE public.quotes 
        ADD CONSTRAINT quotes_status_check 
        CHECK (status IN ('pending', 'accepted', 'rejected', 'expired', 'archived'));
    END IF;
END $$;
