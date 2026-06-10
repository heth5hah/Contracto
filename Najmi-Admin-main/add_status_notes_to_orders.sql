-- Add status_notes column to orders table
-- This column is required to store transport details and other status update notes

ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS status_notes TEXT;

COMMENT ON COLUMN orders.status_notes IS 'Notes about status changes, transport details, or order updates';
