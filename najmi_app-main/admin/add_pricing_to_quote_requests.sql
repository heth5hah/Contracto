-- Add pricing fields to quote_requests table
ALTER TABLE public.quote_requests 
ADD COLUMN IF NOT EXISTS transport_charges DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_amount DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS admin_status TEXT DEFAULT 'new';

-- Note: admin_status might already exist but adding IF NOT EXISTS just in case
