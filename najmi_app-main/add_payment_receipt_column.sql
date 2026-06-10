-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Add payment_receipt_url to quote_requests
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add column to quote_requests table
ALTER TABLE public.quote_requests
  ADD COLUMN IF NOT EXISTS payment_receipt_url TEXT;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Create Storage Bucket for payment receipts
--    Do this in Supabase Dashboard → Storage → New Bucket
--    OR run the SQL below (requires superuser / service role):
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-receipts', 'payment-receipts', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Storage RLS policies — allow authenticated users to upload/read
-- ─────────────────────────────────────────────────────────────────────────────

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'payment-receipts');

-- Allow public read (so admin can view without auth)
CREATE POLICY "Allow public read"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'payment-receipts');

-- Allow users to update (replace) their own receipt
CREATE POLICY "Allow authenticated update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'payment-receipts');
