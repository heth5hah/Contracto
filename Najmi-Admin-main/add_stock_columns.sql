-- Add stock management columns to products table
-- Run this in your Supabase SQL Editor

-- Add stock_status column (default to 'in_stock')
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS stock_status VARCHAR(20) DEFAULT 'in_stock' 
CHECK (stock_status IN ('in_stock', 'out_of_stock'));

-- Add stock_quantity column
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS stock_quantity INTEGER;

-- Add comments to describe the columns
COMMENT ON COLUMN products.stock_status IS 'Stock availability status: in_stock or out_of_stock';
COMMENT ON COLUMN products.stock_quantity IS 'Available quantity in stock (optional)';

-- Create an index for better query performance
CREATE INDEX IF NOT EXISTS idx_products_stock_status ON products(stock_status);

-- Update existing products to have stock_status = 'in_stock' if NULL
UPDATE products 
SET stock_status = 'in_stock' 
WHERE stock_status IS NULL;
