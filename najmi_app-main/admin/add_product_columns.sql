-- Add missing columns to products table
-- Run this in your Supabase SQL editor

ALTER TABLE products 
ADD COLUMN IF NOT EXISTS discount_percent DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS final_price DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS photos TEXT[];

-- Add a comment to describe the new columns
COMMENT ON COLUMN products.discount_percent IS 'Discount percentage applied to MRP (0-100)';
COMMENT ON COLUMN products.final_price IS 'Final calculated price after discount';
COMMENT ON COLUMN products.photos IS 'Array of photo URLs from Supabase storage';

-- Create an index on final_price for better query performance
CREATE INDEX IF NOT EXISTS idx_products_final_price ON products(final_price);

-- Update existing products to have final_price equal to MRP if not set
UPDATE products 
SET final_price = mrp 
WHERE final_price IS NULL AND mrp IS NOT NULL; 