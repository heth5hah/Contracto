-- Migration: Add is_available column to public.quote_items
ALTER TABLE public.quote_items
  ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true;

-- Verify the column was added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'quote_items' AND column_name = 'is_available';
