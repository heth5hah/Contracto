-- EMERGENCY FIX: Create coupons table immediately
-- Run this in Supabase SQL Editor NOW

-- Drop and recreate coupons table
DROP TABLE IF EXISTS coupons CASCADE;

CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('percent', 'fixed')),
  discount_value NUMERIC NOT NULL,
  min_order_amount NUMERIC DEFAULT 0,
  max_discount_amount NUMERIC,
  valid_from TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  valid_until TIMESTAMP WITH TIME ZONE,
  usage_limit INTEGER,
  usage_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Enable all for service role" ON coupons;
DROP POLICY IF EXISTS "Admin full access" ON coupons;
DROP POLICY IF EXISTS "Public read active" ON coupons;

-- Create policies
CREATE POLICY "Enable all for service role" ON coupons
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Admin full access" ON coupons
  FOR ALL 
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public read active" ON coupons
  FOR SELECT 
  TO anon
  USING (is_active = true);

-- Insert sample coupon for testing
INSERT INTO coupons (code, description, discount_type, discount_value, min_order_amount, max_discount_amount, valid_from, valid_until, usage_limit)
VALUES 
  ('WELCOME10', 'Welcome discount - 10% off', 'percent', 10, 500, 100, NOW(), NOW() + INTERVAL '30 days', 100),
  ('FLAT50', 'Flat ₹50 off on orders above ₹1000', 'fixed', 50, 1000, NULL, NOW(), NOW() + INTERVAL '60 days', NULL);

-- Verify
SELECT * FROM coupons;
