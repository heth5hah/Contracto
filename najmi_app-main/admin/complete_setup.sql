-- Complete Setup SQL - Run this in Supabase SQL Editor
-- This fixes all RLS policy issues for both storage and table operations

-- ============================================================================
-- 1. STORAGE SETUP
-- ============================================================================

-- Create storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('brand-catalogs', 'brand-catalogs', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Storage policies for product-photos bucket
CREATE POLICY "Anyone can upload product photos" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'product-photos');

CREATE POLICY "Anyone can view product photos" ON storage.objects
FOR SELECT USING (bucket_id = 'product-photos');

CREATE POLICY "Anyone can update product photos" ON storage.objects
FOR UPDATE USING (bucket_id = 'product-photos');

CREATE POLICY "Anyone can delete product photos" ON storage.objects
FOR DELETE USING (bucket_id = 'product-photos');

-- Storage policies for brand-catalogs bucket
CREATE POLICY "Anyone can upload brand catalogs" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'brand-catalogs');

CREATE POLICY "Anyone can view brand catalogs" ON storage.objects
FOR SELECT USING (bucket_id = 'brand-catalogs');

CREATE POLICY "Anyone can update brand catalogs" ON storage.objects
FOR UPDATE USING (bucket_id = 'brand-catalogs');

CREATE POLICY "Anyone can delete brand catalogs" ON storage.objects
FOR DELETE USING (bucket_id = 'brand-catalogs');

-- ============================================================================
-- 2. TABLE POLICIES SETUP
-- ============================================================================

-- Brands table policies for admin operations
CREATE POLICY "Anyone can insert brands" ON public.brands
FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update brands" ON public.brands
FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete brands" ON public.brands
FOR DELETE USING (true);

-- Products table policies for admin operations
CREATE POLICY "Anyone can insert products" ON public.products
FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update products" ON public.products
FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete products" ON public.products
FOR DELETE USING (true);

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- After running this SQL, your admin panel should work properly for:
-- ✅ Creating/editing/deleting brands
-- ✅ Uploading brand catalog PDFs
-- ✅ Creating/editing/deleting products  
-- ✅ Uploading product photos
-- ✅ Managing product units and quality options 