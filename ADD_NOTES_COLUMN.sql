-- FIX: Add missing 'notes' column to quote_request_items table
-- This is causing the insert to fail

-- First, check current structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'quote_request_items'
ORDER BY ordinal_position;

-- Add the missing 'notes' column
ALTER TABLE quote_request_items 
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Verify the column was added
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'quote_request_items'
ORDER BY ordinal_position;

SELECT 'notes column added successfully!' as status;
