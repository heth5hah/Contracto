-- Simple SQL to create brand-assets storage bucket
-- Run this in your Supabase SQL Editor

-- Step 1: Create the bucket (this should work)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('brand-assets', 'brand-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Step 2: If the above works, you're done!
-- The bucket policies can be set via Supabase Dashboard UI instead of SQL

-- ============================================
-- ALTERNATIVE: Set policies via Dashboard UI
-- ============================================
-- 1. Go to Supabase Dashboard > Storage > brand-assets bucket
-- 2. Click on "Policies" tab
-- 3. Click "New Policy"
-- 4. Choose "For full customization" or use templates
-- 5. Create these policies:

-- Policy 1: Allow INSERT (uploads)
-- Name: "Anyone can upload brand assets"
-- Allowed operation: INSERT
-- Policy definition: true

-- Policy 2: Allow SELECT (downloads/viewing)
-- Name: "Anyone can view brand assets"  
-- Allowed operation: SELECT
-- Policy definition: true

-- Policy 3: Allow UPDATE
-- Name: "Anyone can update brand assets"
-- Allowed operation: UPDATE
-- Policy definition: true

-- Policy 4: Allow DELETE
-- Name: "Anyone can delete brand assets"
-- Allowed operation: DELETE
-- Policy definition: true
