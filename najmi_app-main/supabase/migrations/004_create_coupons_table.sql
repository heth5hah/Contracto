-- Migration: Create coupons table
-- Description: Creates table for managing discount coupons

-- Create coupons table
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) UNIQUE NOT NULL,
  discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value DECIMAL(10,2) NOT NULL CHECK (discount_value > 0),
  min_order_value DECIMAL(10,2) DEFAULT 0,
  max_discount DECIMAL(10,2),
  valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  valid_to TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT TRUE,
  usage_limit INTEGER,
  times_used INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(is_active, valid_from, valid_to);

-- Add RLS policies
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read active coupons
CREATE POLICY "Anyone can read active coupons"
  ON coupons FOR SELECT
  USING (is_active = TRUE AND valid_from <= NOW() AND (valid_to IS NULL OR valid_to >= NOW()));

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_coupons_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER coupons_updated_at
  BEFORE UPDATE ON coupons
  FOR EACH ROW
  EXECUTE FUNCTION update_coupons_updated_at();

-- Add comments
COMMENT ON TABLE coupons IS 'Discount coupons for checkout';
COMMENT ON COLUMN coupons.discount_type IS 'Type of discount: percentage or fixed amount';
COMMENT ON COLUMN coupons.discount_value IS 'Discount value (percentage or fixed amount in rupees)';
COMMENT ON COLUMN coupons.min_order_value IS 'Minimum order value required to use coupon';
COMMENT ON COLUMN coupons.max_discount IS 'Maximum discount amount (for percentage coupons)';
