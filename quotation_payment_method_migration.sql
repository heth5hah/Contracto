-- ============================================================
-- Migration: Add payment_method column to quote_requests
-- Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Add payment_method column to quote_requests (if not exists)
ALTER TABLE quote_requests
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT NULL;

-- Allowed values: 'credit', 'bank_transfer', 'online', 'cod'
-- This records HOW the customer chose to pay when accepting a quotation.

-- 2. Verify the column was added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'quote_requests'
  AND column_name = 'payment_method';

-- ============================================================
-- Optional: Add check constraint (enforces allowed values)
-- ============================================================
-- ALTER TABLE quote_requests
--   ADD CONSTRAINT quote_payment_method_check
--   CHECK (payment_method IN ('credit', 'bank_transfer', 'online', 'cod'));
