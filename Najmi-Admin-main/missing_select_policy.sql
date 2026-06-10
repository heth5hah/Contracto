-- Missing SELECT Policy for Products Table
-- Run this in Supabase SQL Editor

-- Add SELECT policy for products table (this was missing!)
CREATE POLICY "Anyone can view products" ON public.products
FOR SELECT USING (true);

-- Also add SELECT policy for brands table (in case it's missing)
CREATE POLICY "Anyone can view brands" ON public.brands  
FOR SELECT USING (true); 