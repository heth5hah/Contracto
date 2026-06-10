-- Migration: Add transport charges
-- Description: Adds transport/delivery charges to products and quotes

-- Add transport charges to products
ALTER TABLE products ADD COLUMN IF NOT EXISTS transport_charges DECIMAL(10,2) DEFAULT 0;

-- Add transport charges to quotes
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS transport_charges DECIMAL(10,2) DEFAULT 0;

-- Add comments
COMMENT ON COLUMN products.transport_charges IS 'Base transport/delivery charges for this product';
COMMENT ON COLUMN quotes.transport_charges IS 'Transport charges included in this quote';
