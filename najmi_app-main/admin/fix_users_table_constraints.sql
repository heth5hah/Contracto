-- Fix users table constraints to make PAN and GST optional
-- This migration makes the registration process more flexible

-- Drop existing constraints
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_pan_key;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_gst_number_key;

-- Make PAN and GST columns nullable
ALTER TABLE public.users ALTER COLUMN pan DROP NOT NULL;
ALTER TABLE public.users ALTER COLUMN gst_number DROP NOT NULL;

-- Add back unique constraints (simple unique, allowing multiple NULL values)
ALTER TABLE public.users ADD CONSTRAINT users_pan_unique UNIQUE (pan);
ALTER TABLE public.users ADD CONSTRAINT users_gst_number_unique UNIQUE (gst_number);

-- Add comment to document the change
COMMENT ON TABLE public.users IS 'Users table with optional PAN and GST fields';
COMMENT ON COLUMN public.users.pan IS 'PAN number (optional, unique when provided)';
COMMENT ON COLUMN public.users.gst_number IS 'GST number (optional, unique when provided)';

-- Verify the changes
SELECT 
    column_name, 
    is_nullable, 
    data_type,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('pan', 'gst_number');

-- Show success message
DO $$
BEGIN
    RAISE NOTICE 'Users table constraints updated successfully!';
    RAISE NOTICE 'PAN and GST are now optional fields.';
END $$;
