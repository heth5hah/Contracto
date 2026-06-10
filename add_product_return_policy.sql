-- Add the new column for tracking returnability of products
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_returnable BOOLEAN DEFAULT true;

-- Reload Supabase Schema Cache
NOTIFY pgrst, 'reload schema';
