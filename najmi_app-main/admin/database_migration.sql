-- Database Migration: Add brand catalog and product units/variants
-- Run this migration to add new columns to existing tables

-- Add brand catalog column to brands table
ALTER TABLE public.brands 
ADD COLUMN catalog_pdf_url text;

-- Add unit and variants columns to products table
ALTER TABLE public.products 
ADD COLUMN unit text,
ADD COLUMN quality_options jsonb DEFAULT '[]'::jsonb;

-- Update RLS policies to include new columns
-- No additional RLS changes needed as existing policies cover new columns

-- Create storage bucket for brand catalogs if it doesn't exist
-- Note: This needs to be run in Supabase dashboard or via API
-- insert into storage.buckets (id, name, public) values ('brand-catalogs', 'brand-catalogs', true);

-- Create storage bucket for product photos if it doesn't exist  
-- Note: This needs to be run in Supabase dashboard or via API
-- insert into storage.buckets (id, name, public) values ('product-photos', 'product-photos', true); 