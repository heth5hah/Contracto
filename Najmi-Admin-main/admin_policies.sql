-- Admin RLS Policies
-- Run these commands in your Supabase SQL editor to enable admin operations

-- Brands table policies for admin operations
CREATE POLICY "Anyone can insert brands" ON public.brands
FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update brands" ON public.brands
FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete brands" ON public.brands
FOR DELETE USING (true);

-- Products table policies for admin operations (if not already exists)
CREATE POLICY "Anyone can insert products" ON public.products
FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update products" ON public.products
FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete products" ON public.products
FOR DELETE USING (true);

-- Alternative: More secure policies for authenticated users only
-- Uncomment these if you want to restrict to authenticated users only

-- CREATE POLICY "Authenticated users can insert brands" ON public.brands
-- FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- CREATE POLICY "Authenticated users can update brands" ON public.brands
-- FOR UPDATE USING (auth.role() = 'authenticated');

-- CREATE POLICY "Authenticated users can delete brands" ON public.brands
-- FOR DELETE USING (auth.role() = 'authenticated');

-- CREATE POLICY "Authenticated users can insert products" ON public.products
-- FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- CREATE POLICY "Authenticated users can update products" ON public.products
-- FOR UPDATE USING (auth.role() = 'authenticated');

-- CREATE POLICY "Authenticated users can delete products" ON public.products
-- FOR DELETE USING (auth.role() = 'authenticated'); 