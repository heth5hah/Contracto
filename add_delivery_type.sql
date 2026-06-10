-- Add the new column for tracking delivery type (home_delivery or pickup_from_shop)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_type VARCHAR DEFAULT 'home_delivery';

-- Reload Supabase Schema Cache
NOTIFY pgrst, 'reload schema';
