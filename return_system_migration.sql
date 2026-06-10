-- ═══════════════════════════════════════════════════════════════
-- RETURN SYSTEM MIGRATION — Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- 1. Add new columns to returns table
ALTER TABLE returns
  ADD COLUMN IF NOT EXISTS pickup_days integer DEFAULT 3,
  ADD COLUMN IF NOT EXISTS pickup_date date,
  ADD COLUMN IF NOT EXISTS bank_details_submitted boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS refund_amount_final numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refund_transaction_id text,
  ADD COLUMN IF NOT EXISTS refund_processed_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS description text;

-- 2. Create return_bank_details table
CREATE TABLE IF NOT EXISTS return_bank_details (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  return_id uuid NOT NULL REFERENCES returns(id) ON DELETE CASCADE,
  account_holder_name text NOT NULL,
  bank_name text NOT NULL,
  account_number text NOT NULL,
  ifsc_code text NOT NULL,
  upi_id text,
  created_at timestamp with time zone DEFAULT now()
);

-- 3. Enable RLS on return_bank_details
ALTER TABLE return_bank_details ENABLE ROW LEVEL SECURITY;

-- 4. Drop old policies if they exist
DROP POLICY IF EXISTS "Users can insert own bank details" ON return_bank_details;
DROP POLICY IF EXISTS "Users can view own bank details" ON return_bank_details;
DROP POLICY IF EXISTS "Service role can view all bank details" ON return_bank_details;

-- 5. RLS Policies — Allow ALL authenticated users to SELECT (admin needs this)
--    Only owner can INSERT (matched by return's user_id)
CREATE POLICY "Anyone authenticated can view bank details"
  ON return_bank_details FOR SELECT
  USING (auth.role() = 'authenticated' OR auth.role() = 'anon');

CREATE POLICY "Users can insert own bank details"
  ON return_bank_details FOR INSERT
  WITH CHECK (
    return_id IN (
      SELECT r.id FROM returns r
      INNER JOIN users u ON r.user_id = u.id
      WHERE u.email = auth.jwt() ->> 'email'
    )
  );

-- ═══════════════════════════════════════════════════════════════
-- DONE — Run this entire script in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════
