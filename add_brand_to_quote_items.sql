-- Create a migration to add brand information to quote_items table
-- This allows preserving the brand name even when a quote is priced by an admin

ALTER TABLE public.quote_items
ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES public.brands(id),
ADD COLUMN IF NOT EXISTS brand_name TEXT;

-- Add index for brand_id for performance
CREATE INDEX IF NOT EXISTS idx_quote_items_brand_id ON public.quote_items(brand_id);

-- Optional: try to populate brand_id from products table for existing items (best effort)
-- UPDATE public.quote_items qi
-- SET brand_id = p.brand_id
-- FROM public.products p
-- WHERE qi.product_id = p.id AND qi.brand_id IS NULL;

SELECT '✅ brand_id and brand_name columns added to quote_items table!' as status;
