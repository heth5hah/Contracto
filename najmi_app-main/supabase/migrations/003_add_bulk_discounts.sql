-- Migration: Add bulk discount support
-- Description: Adds bulk discount rules to products for quantity-based pricing

-- Add bulk discount rules as JSONB
ALTER TABLE products ADD COLUMN IF NOT EXISTS bulk_discount_rules JSONB DEFAULT '[]'::jsonb;

-- Create index for products with bulk discounts
CREATE INDEX IF NOT EXISTS idx_products_bulk_discounts ON products USING GIN (bulk_discount_rules) WHERE bulk_discount_rules != '[]'::jsonb;

-- Add comment for documentation
COMMENT ON COLUMN products.bulk_discount_rules IS 'Array of bulk discount rules: [{"min_qty": 10, "discount_percent": 5}, {"min_qty": 50, "discount_percent": 10}]';

-- Example bulk discount rules structure:
-- [
--   {"min_qty": 10, "discount_percent": 5},
--   {"min_qty": 50, "discount_percent": 10},
--   {"min_qty": 100, "discount_percent": 15}
-- ]
