-- FIX FOR 5 LAKHS AUTO-ACTIVATION
-- Run this in your Supabase SQL Editor

-- 1. Change the default credit limit from 5,00,000 to 0
ALTER TABLE public.business_credit_accounts ALTER COLUMN credit_limit SET DEFAULT 0.00;

-- 2. Change the default available credit from 5,00,000 to 0
ALTER TABLE public.business_credit_accounts ALTER COLUMN available_credit SET DEFAULT 0.00;

-- 3. Change the default status from 'active' to 'pending'
ALTER TABLE public.business_credit_accounts ALTER COLUMN status SET DEFAULT 'pending';

-- 4. Set any existing untouched 5,00,000 accounts to 0 and pending
UPDATE public.business_credit_accounts
SET 
  credit_limit = 0.00,
  available_credit = 0.00,
  status = 'pending'
WHERE 
  used_credit = 0.00 
  AND credit_limit = 500000.00;
