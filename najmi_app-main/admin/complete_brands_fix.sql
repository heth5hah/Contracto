-- Complete Brands Fix - Run this in Supabase SQL Editor
-- This fixes all issues with brand creation and logo uploads

-- ============================================================================
-- 1. BRANDS TABLE RLS POLICIES
-- ============================================================================

-- Add missing policies for brands table to fix 403 error
CREATE POLICY "Anyone can insert brands" ON public.brands
FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update brands" ON public.brands
FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete brands" ON public.brands
FOR DELETE USING (true);

CREATE POLICY "Anyone can view brands" ON public.brands
FOR SELECT USING (true);

-- ============================================================================
-- 2. STORAGE POLICIES FOR BRAND-LOGOS BUCKET
-- ============================================================================

-- Storage policies for brand-logos bucket (for logo uploads)
CREATE POLICY "Anyone can upload brand logos" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'brand-logos');

CREATE POLICY "Anyone can view brand logos" ON storage.objects
FOR SELECT USING (bucket_id = 'brand-logos');

CREATE POLICY "Anyone can update brand logos" ON storage.objects
FOR UPDATE USING (bucket_id = 'brand-logos');

CREATE POLICY "Anyone can delete brand logos" ON storage.objects
FOR DELETE USING (bucket_id = 'brand-logos');

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- After running this SQL, your brands functionality should work:
-- ✅ Creating/editing/deleting brands (fixes 403 error)
-- ✅ Uploading brand logo images via drag & drop
-- ✅ Uploading brand catalog PDFs  
-- ✅ Viewing existing brand logos and catalogs 