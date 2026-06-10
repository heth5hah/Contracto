-- Migration to update image_slides table to link to brands instead of URLs
-- Run this in your Supabase SQL editor

-- Add brand_id column to image_slides table
ALTER TABLE public.image_slides 
ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES public.brands(id) ON DELETE SET NULL;

-- Add index for brand_id for better performance
CREATE INDEX IF NOT EXISTS idx_image_slides_brand_id ON public.image_slides(brand_id);

-- Optional: Remove link_url column if you want to completely replace it
-- Uncomment the line below if you want to remove the link_url column
-- ALTER TABLE public.image_slides DROP COLUMN IF EXISTS link_url;

-- Update RLS policies to include brand_id
-- The existing policies should work fine, but you can add brand-specific policies if needed

-- Example: If you want to allow users to see which brand a slide links to
-- CREATE POLICY "Image slides brand info is viewable by everyone" ON public.image_slides
--     FOR SELECT USING (true);

-- Note: If you have existing data with link_url values, you'll need to manually 
-- migrate that data to brand_id values before dropping the link_url column
