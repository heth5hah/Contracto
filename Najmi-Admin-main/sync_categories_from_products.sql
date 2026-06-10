-- Script to populate categories table from products table
-- This script will empty the categories table and repopulate it with unique categories and subcategories from products

-- Step 1: Clear existing categories table
TRUNCATE TABLE public.categories CASCADE;

-- Step 2: Insert unique categories from products table
INSERT INTO public.categories (id, name, description, image_url, is_active, created_at, updated_at)
SELECT 
    gen_random_uuid() as id,
    category as name,
    CONCAT('Category for ', category, ' products') as description,
    NULL as image_url,
    true as is_active,
    NOW() as created_at,
    NOW() as updated_at
FROM (
    SELECT DISTINCT category 
    FROM public.products 
    WHERE category IS NOT NULL AND category != ''
) AS unique_categories;

-- Step 3: Drop existing view if it exists and create a new one
DROP VIEW IF EXISTS public.categories_with_counts;

CREATE VIEW public.categories_with_counts AS
SELECT 
    c.id,
    c.name,
    c.description,
    c.image_url,
    c.is_active,
    c.created_at,
    c.updated_at,
    COUNT(p.id)::integer as product_count,
    ARRAY_AGG(DISTINCT p.subcategory ORDER BY p.subcategory) FILTER (WHERE p.subcategory IS NOT NULL AND p.subcategory != '') as subcategories
FROM public.categories c
LEFT JOIN public.products p ON c.name = p.category
GROUP BY c.id, c.name, c.description, c.image_url, c.is_active, c.created_at, c.updated_at;

-- Step 4: Create a function to sync categories when products are updated
CREATE OR REPLACE FUNCTION sync_categories_from_products()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle INSERT and UPDATE operations
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- Insert new category if it doesn't exist
        INSERT INTO public.categories (id, name, description, image_url, is_active, created_at, updated_at)
        SELECT 
            gen_random_uuid(),
            NEW.category,
            CONCAT('Category for ', NEW.category, ' products'),
            NULL,
            true,
            NOW(),
            NOW()
        WHERE NEW.category IS NOT NULL 
        AND NEW.category != ''
        AND NOT EXISTS (
            SELECT 1 FROM public.categories WHERE name = NEW.category
        );
        
        -- Update the updated_at timestamp for existing category
        UPDATE public.categories 
        SET updated_at = NOW()
        WHERE name = NEW.category;
    END IF;
    
    -- Handle DELETE operations
    IF TG_OP = 'DELETE' THEN
        -- Check if category still has products, if not, mark as inactive
        UPDATE public.categories 
        SET is_active = false, updated_at = NOW()
        WHERE name = OLD.category
        AND NOT EXISTS (
            SELECT 1 FROM public.products WHERE category = OLD.category
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create triggers to automatically sync categories
DROP TRIGGER IF EXISTS sync_categories_on_product_insert ON public.products;
CREATE TRIGGER sync_categories_on_product_insert
    AFTER INSERT ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION sync_categories_from_products();

DROP TRIGGER IF EXISTS sync_categories_on_product_update ON public.products;
CREATE TRIGGER sync_categories_on_product_update
    AFTER UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION sync_categories_from_products();

DROP TRIGGER IF EXISTS sync_categories_on_product_delete ON public.products;
CREATE TRIGGER sync_categories_on_product_delete
    AFTER DELETE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION sync_categories_from_products();

-- Step 6: Create a function to sync products when categories are updated
CREATE OR REPLACE FUNCTION sync_products_from_categories()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle category name changes
    IF TG_OP = 'UPDATE' AND OLD.name != NEW.name THEN
        -- Update all products with the old category name to use the new name
        UPDATE public.products 
        SET category = NEW.name, updated_at = NOW()
        WHERE category = OLD.name;
    END IF;
    
    -- Handle category deletion
    IF TG_OP = 'DELETE' THEN
        -- Set category to NULL for products that were using this category
        UPDATE public.products 
        SET category = NULL, updated_at = NOW()
        WHERE category = OLD.name;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create triggers to sync products when categories change
DROP TRIGGER IF EXISTS sync_products_on_category_update ON public.categories;
CREATE TRIGGER sync_products_on_category_update
    AFTER UPDATE ON public.categories
    FOR EACH ROW
    EXECUTE FUNCTION sync_products_from_categories();

DROP TRIGGER IF EXISTS sync_products_on_category_delete ON public.categories;
CREATE TRIGGER sync_products_on_category_delete
    AFTER DELETE ON public.categories
    FOR EACH ROW
    EXECUTE FUNCTION sync_products_from_categories();

-- Step 8: Create a manual sync function for one-time operations
CREATE OR REPLACE FUNCTION manual_sync_categories()
RETURNS void AS $$
BEGIN
    -- Clear and repopulate categories
    TRUNCATE TABLE public.categories CASCADE;
    
    INSERT INTO public.categories (id, name, description, image_url, is_active, created_at, updated_at)
    SELECT 
        gen_random_uuid() as id,
        category as name,
        CONCAT('Category for ', category, ' products') as description,
        NULL as image_url,
        true as is_active,
        NOW() as created_at,
        NOW() as updated_at
    FROM (
        SELECT DISTINCT category 
        FROM public.products 
        WHERE category IS NOT NULL AND category != ''
    ) AS unique_categories;
    
    -- Recreate the view to ensure it has the correct structure
    DROP VIEW IF EXISTS public.categories_with_counts;
    
    CREATE VIEW public.categories_with_counts AS
    SELECT 
        c.id,
        c.name,
        c.description,
        c.image_url,
        c.is_active,
        c.created_at,
        c.updated_at,
        COUNT(p.id)::integer as product_count,
        ARRAY_AGG(DISTINCT p.subcategory ORDER BY p.subcategory) FILTER (WHERE p.subcategory IS NOT NULL AND p.subcategory != '') as subcategories
    FROM public.categories c
    LEFT JOIN public.products p ON c.name = p.category
    GROUP BY c.id, c.name, c.description, c.image_url, c.is_active, c.created_at, c.updated_at;
    
    RAISE NOTICE 'Categories synced successfully from products table';
END;
$$ LANGUAGE plpgsql;

-- Step 9: Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories TO authenticated;
GRANT SELECT ON public.categories_with_counts TO authenticated;
GRANT EXECUTE ON FUNCTION sync_categories_from_products() TO authenticated;
GRANT EXECUTE ON FUNCTION sync_products_from_categories() TO authenticated;
GRANT EXECUTE ON FUNCTION manual_sync_categories() TO authenticated;

-- Step 10: Run the initial sync
SELECT manual_sync_categories();

-- Verification query to check the results
SELECT 
    c.name as category_name,
    c.product_count,
    array_length(c.subcategories, 1) as subcategory_count,
    c.subcategories
FROM public.categories_with_counts c
ORDER BY c.product_count DESC;
