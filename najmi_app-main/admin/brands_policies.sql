-- Fix Brands Table RLS Policies
-- Run this in Supabase SQL Editor to fix the 403 error

-- Add missing policies for brands table
CREATE POLICY "Anyone can insert brands" ON public.brands
FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update brands" ON public.brands
FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete brands" ON public.brands
FOR DELETE USING (true);

CREATE POLICY "Anyone can view brands" ON public.brands
FOR SELECT USING (true); 