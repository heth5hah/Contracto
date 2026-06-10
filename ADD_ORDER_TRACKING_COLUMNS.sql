-- Add tracking columns to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS estimated_delivery TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS tracking_milestones JSONB DEFAULT '{}'::jsonb;

-- Update RLS policies if necessary (assuming they already allow SELECT/UPDATE)
-- This is just for schema consistency.
