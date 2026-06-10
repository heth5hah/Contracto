-- FINAL CLEANUP AND FIX FOR BRAND RELATIONSHIPS
-- This script ensures exactly ONE clean relationship exists for brand joins

DO $$ 
BEGIN 
    -- 1. CLEANUP quote_items
    -- Drop all potential conflicting constraints
    ALTER TABLE IF EXISTS public.quote_items DROP CONSTRAINT IF EXISTS fk_quote_items_brand;
    ALTER TABLE IF EXISTS public.quote_items DROP CONSTRAINT IF EXISTS quote_items_brand_id_fkey;
    
    -- Ensure columns exist (just in case)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'quote_items' AND column_name = 'brand_id') THEN
        ALTER TABLE public.quote_items ADD COLUMN brand_id UUID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'quote_items' AND column_name = 'brand_name') THEN
        ALTER TABLE public.quote_items ADD COLUMN brand_name TEXT;
    END IF;

    -- Add back exactly ONE constraint
    ALTER TABLE public.quote_items
    ADD CONSTRAINT quote_items_brand_id_fkey
    FOREIGN KEY (brand_id) REFERENCES public.brands(id);


    -- 2. CLEANUP quote_request_items
    -- Drop all potential conflicting constraints
    ALTER TABLE IF EXISTS public.quote_request_items DROP CONSTRAINT IF EXISTS fk_quote_request_items_brand;
    ALTER TABLE IF EXISTS public.quote_request_items DROP CONSTRAINT IF EXISTS quote_request_items_brand_id_fkey;

    -- Ensure brand_id column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'quote_request_items' AND column_name = 'brand_id') THEN
        ALTER TABLE public.quote_request_items ADD COLUMN brand_id UUID;
    END IF;

    -- Add back exactly ONE constraint
    ALTER TABLE public.quote_request_items
    ADD CONSTRAINT quote_request_items_brand_id_fkey
    FOREIGN KEY (brand_id) REFERENCES public.brands(id);

END $$;

SELECT '✅ Brand relationships normalized! Please restart the admin app.' as status;
