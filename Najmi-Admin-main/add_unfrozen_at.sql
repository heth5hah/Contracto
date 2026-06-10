-- Migration: Add unfrozen_at column to business_credit_accounts table
-- Run this in Supabase SQL Editor

-- 1. Add unfrozen_at column to business_credit_accounts table
ALTER TABLE public.business_credit_accounts
  ADD COLUMN IF NOT EXISTS unfrozen_at timestamp with time zone;

-- 2. Verify the column was added
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'business_credit_accounts' AND column_name = 'unfrozen_at';
