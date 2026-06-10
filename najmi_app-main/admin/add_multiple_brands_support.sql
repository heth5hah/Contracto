-- Add support for multiple brands per product
-- This migration adds a new field to store multiple brand IDs

-- Add brand_ids field to products table (JSON array)
ALTER TABLE products 
ADD COLUMN brand_ids JSONB DEFAULT '[]'::jsonb;

-- Add index for brand_ids for better performance
CREATE INDEX idx_products_brand_ids ON products USING GIN (brand_ids);

-- Migrate existing single brand_id to brand_ids array
UPDATE products 
SET brand_ids = CASE 
    WHEN brand_id IS NOT NULL THEN jsonb_build_array(brand_id::text)
    ELSE '[]'::jsonb
END
WHERE brand_ids IS NULL;

-- Add comment to document the new field
COMMENT ON COLUMN products.brand_ids IS 'Array of brand IDs for multiple brand support';

-- Optional: Create a view to make it easier to query products with brands
CREATE OR REPLACE VIEW products_with_brands AS
SELECT 
    p.*,
    jsonb_agg(b.name) as brand_names
FROM products p
LEFT JOIN brands b ON b.id::text = ANY(SELECT jsonb_array_elements_text(p.brand_ids))
GROUP BY p.id;

-- Add function to get brand names for a product
CREATE OR REPLACE FUNCTION get_product_brand_names(product_id UUID)
RETURNS TEXT[] AS $$
BEGIN
    RETURN (
        SELECT array_agg(b.name)
        FROM products p
        LEFT JOIN brands b ON b.id::text = ANY(SELECT jsonb_array_elements_text(p.brand_ids))
        WHERE p.id = product_id
    );
END;
$$ LANGUAGE plpgsql; 