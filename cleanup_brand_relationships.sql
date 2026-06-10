-- Cleanup script to resolve relationship ambiguity
-- This removes the duplicate foreign keys added in the previous step

-- 1. Cleanup quote_request_items
ALTER TABLE public.quote_request_items
DROP CONSTRAINT IF EXISTS fk_quote_request_items_brand;

-- 2. Cleanup quote_items
ALTER TABLE public.quote_items
DROP CONSTRAINT IF EXISTS fk_quote_items_brand;

-- 3. Ensure standard names exist if needed (they likely already do based on the error)
-- No action needed if standard *_fkey exists.

SELECT '✅ Duplicate foreign key constraints removed!' as status;
