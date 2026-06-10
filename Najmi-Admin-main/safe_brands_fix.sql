-- Safe Brands Fix - Run this in Supabase SQL Editor
-- This safely handles existing policies and fixes all brand issues

-- ============================================================================
-- 1. SAFELY CREATE BRANDS TABLE RLS POLICIES
-- ============================================================================

-- Drop existing policies if they exist (ignore errors)
DROP POLICY IF EXISTS "Anyone can insert brands" ON public.brands;
DROP POLICY IF EXISTS "Anyone can update brands" ON public.brands;
DROP POLICY IF EXISTS "Anyone can delete brands" ON public.brands;
DROP POLICY IF EXISTS "Anyone can view brands" ON public.brands;

-- Create fresh policies for brands table
CREATE POLICY "Anyone can insert brands" ON public.brands
FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update brands" ON public.brands
FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete brands" ON public.brands
FOR DELETE USING (true);

CREATE POLICY "Anyone can view brands" ON public.brands
FOR SELECT USING (true);

-- ============================================================================
-- 2. SAFELY CREATE STORAGE POLICIES FOR BRAND-LOGOS BUCKET
-- ============================================================================

-- Drop existing storage policies if they exist (ignore errors)
DROP POLICY IF EXISTS "Anyone can upload brand logos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view brand logos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can update brand logos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can delete brand logos" ON storage.objects;

-- Create fresh storage policies for brand-logos bucket
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
-- This script safely recreates all necessary policies:
-- ✅ Brands table INSERT/UPDATE/DELETE/SELECT policies
-- ✅ Brand-logos storage policies for image uploads
-- ✅ Handles existing policies without errors 