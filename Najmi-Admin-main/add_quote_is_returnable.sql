-- Migration: Add is_returnable column to quotes table
-- Run this in Supabase SQL Editor

-- 1. Add is_returnable column to quotes table
ALTER TABLE public.quotes
  ADD COLUMN IF NOT EXISTS is_returnable boolean NOT NULL DEFAULT true;

-- 2. Ensure existing quotes are marked as returnable (safe default)
UPDATE public.quotes SET is_returnable = true WHERE is_returnable IS NULL;

-- 3. Verify the column was added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'quotes' AND column_name = 'is_returnable';
