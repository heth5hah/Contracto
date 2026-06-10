-- Add new pricing and stock status fields to products table
-- This migration adds support for different pricing types and stock status

-- Add stock_status field
ALTER TABLE products 
ADD COLUMN stock_status VARCHAR(20) DEFAULT 'in_stock' CHECK (stock_status IN ('in_stock', 'out_of_stock'));

-- Add pricing_type field
ALTER TABLE products 
ADD COLUMN pricing_type VARCHAR(20) DEFAULT 'fixed_price' CHECK (pricing_type IN ('fixed_price', 'whatsapp_request', 'quote_request'));

-- Add WhatsApp message field for WhatsApp request type
ALTER TABLE products 
ADD COLUMN whatsapp_message TEXT;

-- Add quote instructions field for quote request type
ALTER TABLE products 
ADD COLUMN quote_instructions TEXT;

-- Update existing products to have default values
UPDATE products 
SET 
    stock_status = 'in_stock',
    pricing_type = 'fixed_price'
WHERE stock_status IS NULL OR pricing_type IS NULL;

-- Add indexes for better performance
CREATE INDEX idx_products_stock_status ON products(stock_status);
CREATE INDEX idx_products_pricing_type ON products(pricing_type);
CREATE INDEX idx_products_brand_id ON products(brand_id);

-- Add comment to document the new fields
COMMENT ON COLUMN products.stock_status IS 'Stock status: in_stock or out_of_stock';
COMMENT ON COLUMN products.pricing_type IS 'Pricing type: fixed_price, whatsapp_request, or quote_request';
COMMENT ON COLUMN products.whatsapp_message IS 'Custom WhatsApp message for whatsapp_request pricing type';
COMMENT ON COLUMN products.quote_instructions IS 'Instructions for quote requests'; 