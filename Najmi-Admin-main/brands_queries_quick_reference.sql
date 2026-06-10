-- =====================================================
-- BRANDS AND PRODUCTS - QUICK REFERENCE QUERIES
-- =====================================================
-- Common SQL queries for managing brands and products in the admin panel
-- 
-- ⚠️  IMPORTANT: This file contains EXAMPLE queries with placeholders.
-- ⚠️  DO NOT run queries with 'YOUR-BRAND-ID-HERE' or 'YOUR-PRODUCT-ID-HERE' as-is!
-- ⚠️  Replace these placeholders with actual UUIDs before executing.
-- 
-- Safe queries (can be run directly):
-- - Lines 10-27: View all brands with product counts
-- - Lines 32: Get all brands
-- - Lines 37-40: Get all active brands
-- 
-- Example queries (MUST modify before running):
-- - All queries with 'YOUR-BRAND-ID-HERE' or 'YOUR-PRODUCT-ID-HERE'
-- =====================================================

-- =====================================================
-- VIEW ALL BRANDS WITH PRODUCT COUNTS
-- =====================================================
SELECT 
    b.id,
    b.name,
    b.logo_url,
    b.description,
    b.is_active,
    b.created_at,
    COUNT(DISTINCT p.id) FILTER (
        WHERE p.brand_id = b.id 
        OR b.id::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
    ) as product_count
FROM public.brands b
LEFT JOIN public.products p ON (
    p.brand_id = b.id 
    OR b.id::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
)
GROUP BY b.id, b.name, b.logo_url, b.description, b.is_active, b.created_at
ORDER BY b.name;

-- =====================================================
-- GET ALL BRANDS (SIMPLE)
-- =====================================================
SELECT * FROM public.brands ORDER BY name;

-- =====================================================
-- GET ALL ACTIVE BRANDS (FOR DROPDOWNS)
-- =====================================================
SELECT id, name, logo_url 
FROM public.brands 
WHERE is_active = true 
ORDER BY name;

-- =====================================================
-- GET PRODUCTS FOR A SPECIFIC BRAND
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'YOUR-BRAND-ID-HERE' with actual brand UUID before running!
-- Example: WHERE p.brand_id = '123e4567-e89b-12d3-a456-426614174000'
/*
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
    p.created_at
FROM public.products p
WHERE p.brand_id = 'YOUR-BRAND-ID-HERE'
   OR 'YOUR-BRAND-ID-HERE'::text = ANY(
       SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb))
   )
ORDER BY p.product_name;
*/

-- =====================================================
-- ADD A NEW BRAND
-- =====================================================
INSERT INTO public.brands (name, description, logo_url, is_active)
VALUES ('Brand Name', 'Brand description', 'https://example.com/logo.png', true)
RETURNING *;

-- =====================================================
-- UPDATE A BRAND
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'YOUR-BRAND-ID-HERE' with actual brand UUID before running!
/*
UPDATE public.brands 
SET 
    name = 'Updated Brand Name',
    description = 'Updated description',
    logo_url = 'https://example.com/new-logo.png',
    is_active = true,
    updated_at = NOW()
WHERE id = 'YOUR-BRAND-ID-HERE'
RETURNING *;
*/

-- =====================================================
-- DELETE A BRAND (CAREFUL!)
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'YOUR-BRAND-ID-HERE' with actual brand UUID before running!
-- Note: This will fail if products are still associated with this brand
-- You may need to update or delete associated products first
/*
DELETE FROM public.brands 
WHERE id = 'YOUR-BRAND-ID-HERE'
RETURNING *;
*/

-- =====================================================
-- ADD A PRODUCT TO A BRAND (SINGLE BRAND)
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'YOUR-BRAND-ID-HERE' with actual brand UUID before running!
/*
INSERT INTO public.products (
    product_name, 
    brand_id, 
    category, 
    description, 
    mrp, 
    final_price,
    discount_percent,
    is_active,
    photos
)
VALUES (
    'Product Name',
    'YOUR-BRAND-ID-HERE',
    'Category Name',
    'Product description',
    1000.00,
    900.00,
    10.00,
    true,
    ARRAY['https://example.com/image1.jpg', 'https://example.com/image2.jpg']
)
RETURNING *;
*/

-- =====================================================
-- ADD A PRODUCT WITH MULTIPLE BRANDS
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'BRAND-ID-1' and 'BRAND-ID-2' with actual brand UUIDs before running!
/*
INSERT INTO public.products (
    product_name, 
    brand_ids, 
    category, 
    description, 
    mrp, 
    final_price,
    discount_percent,
    is_active,
    photos
)
VALUES (
    'Product Name',
    '["BRAND-ID-1", "BRAND-ID-2"]'::jsonb,
    'Category Name',
    'Product description',
    1000.00,
    900.00,
    10.00,
    true,
    ARRAY['https://example.com/image1.jpg']
)
RETURNING *;
*/

-- =====================================================
-- UPDATE A PRODUCT'S BRAND ASSOCIATION
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace placeholders with actual UUIDs before running!
/*
UPDATE public.products 
SET 
    brand_id = 'YOUR-BRAND-ID-HERE',
    brand_ids = '["YOUR-BRAND-ID-HERE"]'::jsonb,
    updated_at = NOW()
WHERE id = 'YOUR-PRODUCT-ID-HERE'
RETURNING *;
*/

-- =====================================================
-- SEARCH BRANDS BY NAME
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'search-term' with your actual search query before running!
-- Example: WHERE LOWER(name) LIKE LOWER('%guardian%')
/*
SELECT * 
FROM public.brands 
WHERE LOWER(name) LIKE LOWER('%search-term%') 
ORDER BY name;
*/

-- =====================================================
-- GET PRODUCT COUNT PER BRAND
-- =====================================================
SELECT 
    b.id,
    b.name,
    COUNT(DISTINCT p.id) as product_count
FROM public.brands b
LEFT JOIN public.products p ON (
    p.brand_id = b.id 
    OR b.id::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
)
GROUP BY b.id, b.name
ORDER BY product_count DESC, b.name;

-- =====================================================
-- GET BRAND DETAILS WITH ALL PRODUCTS (USING FUNCTION)
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'YOUR-BRAND-ID-HERE' with actual brand UUID before running!
-- Example: SELECT * FROM get_brand_details_with_products('123e4567-e89b-12d3-a456-426614174000');
/*
SELECT * FROM get_brand_details_with_products('YOUR-BRAND-ID-HERE');
*/

-- =====================================================
-- TOGGLE BRAND ACTIVE STATUS
-- =====================================================
-- ⚠️ EXAMPLE QUERY - Replace 'YOUR-BRAND-ID-HERE' with actual brand UUID before running!
/*
UPDATE public.brands 
SET 
    is_active = NOT is_active,
    updated_at = NOW()
WHERE id = 'YOUR-BRAND-ID-HERE'
RETURNING id, name, is_active;
*/

-- =====================================================
-- GET BRANDS WITH NO PRODUCTS
-- =====================================================
SELECT b.*
FROM public.brands b
LEFT JOIN public.products p ON (
    p.brand_id = b.id 
    OR b.id::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
)
WHERE p.id IS NULL
ORDER BY b.name;

-- =====================================================
-- GET TOP BRANDS BY PRODUCT COUNT
-- =====================================================
SELECT 
    b.id,
    b.name,
    b.logo_url,
    COUNT(DISTINCT p.id) as product_count
FROM public.brands b
LEFT JOIN public.products p ON (
    p.brand_id = b.id 
    OR b.id::text = ANY(SELECT jsonb_array_elements_text(COALESCE(p.brand_ids, '[]'::jsonb)))
)
WHERE b.is_active = true
GROUP BY b.id, b.name, b.logo_url
HAVING COUNT(DISTINCT p.id) > 0
ORDER BY product_count DESC
LIMIT 10;

