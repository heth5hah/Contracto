-- Migration: Ensure quote notes field exists
-- Description: Ensures quote_requests table has notes field for user instructions

-- Add notes field if it doesn't exist (may already exist from previous migrations)
ALTER TABLE quote_requests ADD COLUMN IF NOT EXISTS notes TEXT;

-- Add comment
COMMENT ON COLUMN quote_requests.notes IS 'Special instructions or notes from user for this quote request';
