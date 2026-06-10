-- Table Policies Only - Run this in Supabase SQL Editor
-- This should work with your current permission level

-- Create storage bucket (this should work)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('brand-catalogs', 'brand-catalogs', true)
ON CONFLICT (id) DO NOTHING;

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