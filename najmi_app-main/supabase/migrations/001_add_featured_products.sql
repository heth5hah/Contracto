-- Migration: Add featured products support
-- Description: Adds is_featured flag to products table for highlighting featured products

-- Add featured flag to products table
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE;

-- Create index for better query performance on featured products
CREATE INDEX IF NOT EXISTS idx_products_featured ON products(is_featured) WHERE is_featured = TRUE;

-- Add comment for documentation
COMMENT ON COLUMN products.is_featured IS 'Flag to mark products as featured for display on home screen';
