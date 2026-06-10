-- Storage Policies for File Uploads
-- Run these commands in your Supabase SQL editor to enable file uploads

-- Create storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('brand-catalogs', 'brand-catalogs', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy for product-photos bucket (allows public uploads and reads)
CREATE POLICY "Anyone can upload product photos" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'product-photos');

CREATE POLICY "Anyone can view product photos" ON storage.objects
FOR SELECT USING (bucket_id = 'product-photos');

CREATE POLICY "Anyone can update product photos" ON storage.objects
FOR UPDATE USING (bucket_id = 'product-photos');

CREATE POLICY "Anyone can delete product photos" ON storage.objects
FOR DELETE USING (bucket_id = 'product-photos');

-- Policy for brand-catalogs bucket (allows public uploads and reads)
CREATE POLICY "Anyone can upload brand catalogs" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'brand-catalogs');

CREATE POLICY "Anyone can view brand catalogs" ON storage.objects
FOR SELECT USING (bucket_id = 'brand-catalogs');

CREATE POLICY "Anyone can update brand catalogs" ON storage.objects
FOR UPDATE USING (bucket_id = 'brand-catalogs');

CREATE POLICY "Anyone can delete brand catalogs" ON storage.objects
FOR DELETE USING (bucket_id = 'brand-catalogs');

-- Additional policy for authenticated users (more secure option)
-- Uncomment these if you want to restrict to authenticated users only

-- CREATE POLICY "Authenticated users can upload product photos" ON storage.objects
-- FOR INSERT WITH CHECK (bucket_id = 'product-photos' AND auth.role() = 'authenticated');

-- CREATE POLICY "Authenticated users can upload brand catalogs" ON storage.objects
-- FOR INSERT WITH CHECK (bucket_id = 'brand-catalogs' AND auth.role() = 'authenticated'); 