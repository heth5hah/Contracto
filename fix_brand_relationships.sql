-- Migration to fix missing foreign key relationships for brands
-- This allows Supabase to perform auto-joins in the admin app

-- 1. Fix quote_items table
DO $$ 
BEGIN 
    -- Check if brand_id exists before adding constraint
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'quote_items' AND column_name = 'brand_id') THEN
        -- Add foreign key constraint if it doesn't already exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'quote_items' AND constraint_name = 'fk_quote_items_brand') THEN
            ALTER TABLE public.quote_items
            ADD CONSTRAINT fk_quote_items_brand
            FOREIGN KEY (brand_id) 
            REFERENCES public.brands(id);
        END IF;
    END IF;
END $$;

-- 2. Fix quote_request_items table
DO $$ 
BEGIN 
    -- Check if brand_id exists before adding constraint
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'quote_request_items' AND column_name = 'brand_id') THEN
        -- Add foreign key constraint if it doesn't already exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'quote_request_items' AND constraint_name = 'fk_quote_request_items_brand') THEN
            ALTER TABLE public.quote_request_items
            ADD CONSTRAINT fk_quote_request_items_brand
            FOREIGN KEY (brand_id) 
            REFERENCES public.brands(id);
        END IF;
    END IF;
END $$;

SELECT '✅ Foreign key relationships fixed for quote_items and quote_request_items!' as status;
