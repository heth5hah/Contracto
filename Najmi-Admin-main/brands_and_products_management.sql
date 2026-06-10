-- =====================================================
-- BRANDS AND PRODUCTS MANAGEMENT FOR ADMIN PANEL
-- =====================================================
-- This SQL file provides:
-- 1. RLS Policies for admin access to brands and products
-- 2. Useful queries for viewing brands with product counts
-- 3. Queries for managing brands and their products
-- =====================================================

-- =====================================================
-- 1. RLS POLICIES FOR BRANDS TABLE
-- =====================================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Admins can view all brands" ON public.brands;
DROP POLICY IF EXISTS "Admins can insert brands" ON public.brands;
DROP POLICY IF EXISTS "Admins can update brands" ON public.brands;
DROP POLICY IF EXISTS "Admins can delete brands" ON public.brands;
DROP POLICY IF EXISTS "Anyone can view brands" ON public.brands;
DROP POLICY IF EXISTS "Anyone can insert brands" ON public.brands;
DROP POLICY IF EXISTS "Anyone can update brands" ON public.brands;
DROP POLICY IF EXISTS "Anyone can delete brands" ON public.brands;

-- Policy: Admins can view ALL brands (including inactive ones)
CREATE POLICY "Admins can view all brands" ON public.brands
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can insert brands
CREATE POLICY "Admins can insert brands" ON public.brands
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can update brands
CREATE POLICY "Admins can update brands" ON public.brands
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can delete brands
CREATE POLICY "Admins can delete brands" ON public.brands
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- =====================================================
-- 2. RLS POLICIES FOR PRODUCTS TABLE
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can view all products" ON public.products;
DROP POLICY IF EXISTS "Admins can insert products" ON public.products;
DROP POLICY IF EXISTS "Admins can update products" ON public.products;
DROP POLICY IF EXISTS "Admins can delete products" ON public.products;

-- Policy: Admins can view ALL products (including inactive ones)
CREATE POLICY "Admins can view all products" ON public.products
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can insert products
CREATE POLICY "Admins can insert products" ON public.products
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can update products
CREATE POLICY "Admins can update products" ON public.products
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can delete products
CREATE POLICY "Admins can delete products" ON public.products
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- =====================================================
-- 3. USEFUL QUERIES FOR ADMIN PANEL
-- =====================================================

-- Query 1: Get all brands with product counts
-- This query shows all brands and how many products belong to each brand
CREATE OR REPLACE VIEW brands_with_product_counts AS
SELECT 
    b.id,
    b.name,
    b.logo_url,
    b.description,
    b.is_active,
    b.created_at,
    b.updated_at,
    b.catalog_pdf_url,
    COUNT(DISTINCT p.id) FILTER (WHERE p.brand_id = b.id OR b.id::text = ANY(SELECT jsonb_array_elements_text(p.brand_ids))) as product_count
FROM public.brands b
LEFT JOIN public.products p ON (
    p.brand_id = b.id 
    OR b.id::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
)
GROUP BY b.id, b.name, b.logo_url, b.description, b.is_active, b.created_at, b.updated_at, b.catalog_pdf_url
ORDER BY b.name;

-- Query 2: Get products for a specific brand
-- Usage: SELECT * FROM products_for_brand('brand-uuid-here')
CREATE OR REPLACE FUNCTION get_products_for_brand(brand_uuid UUID)
RETURNS TABLE (
    id UUID,
    product_name TEXT,
    category TEXT,
    description TEXT,
    mrp NUMERIC,
    final_price NUMERIC,
    discount_percent NUMERIC,
    photos TEXT[],
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.product_name,
        p.category,
        p.description,
        p.mrp,
        p.final_price,
        p.discount_percent,
        p.photos,
        p.is_active,
        p.created_at,
        p.updated_at
    FROM public.products p
    WHERE p.brand_id = brand_uuid
       OR brand_uuid::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
    ORDER BY p.product_name;
END;
$$ LANGUAGE plpgsql;

-- Query 3: Get brand details with all associated products
-- Usage: SELECT * FROM brand_details_with_products('brand-uuid-here')
CREATE OR REPLACE FUNCTION get_brand_details_with_products(brand_uuid UUID)
RETURNS JSONB AS $$
DECLARE
    brand_data JSONB;
    products_data JSONB;
BEGIN
    -- Get brand details
    SELECT to_jsonb(b.*) INTO brand_data
    FROM public.brands b
    WHERE b.id = brand_uuid;
    
    -- Get products for this brand
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'product_name', p.product_name,
            'category', p.category,
            'description', p.description,
            'mrp', p.mrp,
            'final_price', p.final_price,
            'discount_percent', p.discount_percent,
            'photos', p.photos,
            'is_active', p.is_active,
            'created_at', p.created_at,
            'updated_at', p.updated_at
        )
    ) INTO products_data
    FROM public.products p
    WHERE p.brand_id = brand_uuid
       OR brand_uuid::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
    ORDER BY p.product_name;
    
    -- Combine brand and products
    RETURN jsonb_build_object(
        'brand', brand_data,
        'products', COALESCE(products_data, '[]'::jsonb),
        'product_count', jsonb_array_length(COALESCE(products_data, '[]'::jsonb))
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. HELPER QUERIES FOR COMMON OPERATIONS
-- =====================================================

-- Query to add a new brand
-- Example usage:
-- INSERT INTO public.brands (name, description, logo_url, is_active)
-- VALUES ('New Brand', 'Brand description', 'https://example.com/logo.png', true);

-- Query to update a brand
-- Example usage:
-- UPDATE public.brands 
-- SET name = 'Updated Brand Name', description = 'Updated description', is_active = true
-- WHERE id = 'brand-uuid-here';

-- Query to add a product to a brand
-- Example usage (using brand_id):
-- INSERT INTO public.products (product_name, brand_id, category, description, mrp, final_price, discount_percent, is_active)
-- VALUES ('Product Name', 'brand-uuid-here', 'Category Name', 'Product description', 1000.00, 900.00, 10.00, true);

-- Query to add a product with multiple brands (using brand_ids)
-- Example usage:
-- INSERT INTO public.products (product_name, brand_ids, category, description, mrp, final_price, discount_percent, is_active)
-- VALUES (
--     'Product Name', 
--     '["brand-uuid-1", "brand-uuid-2"]'::jsonb, 
--     'Category Name', 
--     'Product description', 
--     1000.00, 
--     900.00,
--     10.00,
--     true
-- );

-- Query to update a product's brand association
-- Example usage (single brand):
-- UPDATE public.products 
-- SET brand_id = 'new-brand-uuid-here'
-- WHERE id = 'product-uuid-here';

-- Example usage (multiple brands):
-- UPDATE public.products 
-- SET brand_ids = '["brand-uuid-1", "brand-uuid-2"]'::jsonb
-- WHERE id = 'product-uuid-here';

-- Query to get all active brands (for dropdowns/selects)
-- SELECT id, name, logo_url FROM public.brands WHERE is_active = true ORDER BY name;

-- Query to get all brands (active and inactive) for admin panel
-- SELECT * FROM brands_with_product_counts ORDER BY is_active DESC, name;

-- Query to search brands by name
-- SELECT * FROM public.brands WHERE LOWER(name) LIKE LOWER('%search-term%') ORDER BY name;

-- Query to get products count per brand
-- SELECT b.id, b.name, COUNT(p.id) as product_count
-- FROM public.brands b
-- LEFT JOIN public.products p ON p.brand_id = b.id OR b.id::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
-- GROUP BY b.id, b.name
-- ORDER BY product_count DESC;

-- =====================================================
-- 5. INDEXES FOR BETTER PERFORMANCE
-- =====================================================

-- Index on brands.name for faster searches
CREATE INDEX IF NOT EXISTS idx_brands_name ON public.brands(name);

-- Index on brands.is_active for filtering
CREATE INDEX IF NOT EXISTS idx_brands_is_active ON public.brands(is_active);

-- Index on products.brand_id for faster brand-product joins
CREATE INDEX IF NOT EXISTS idx_products_brand_id ON public.products(brand_id);

-- Index on products.brand_ids (GIN index for JSONB array searches)
CREATE INDEX IF NOT EXISTS idx_products_brand_ids ON public.products USING GIN (brand_ids);

-- Index on products.is_active for filtering
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.products(is_active);

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE 'Brands and Products Management SQL setup completed successfully!';
    RAISE NOTICE 'RLS policies created for admin access to brands and products.';
    RAISE NOTICE 'Views and functions created for easier brand and product management.';
    RAISE NOTICE 'Indexes created for better query performance.';
END $$;

