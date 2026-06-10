-- RESILIENT COUPON SYNCHRONIZATION SCRIPT
-- This script handles renaming, missing columns, and constraint updates safely.

-- 1. Ensure all expected columns exist (even if they have old names)
DO $$ 
BEGIN
    -- Rename min_order_amount to min_order_value if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coupons' AND column_name = 'min_order_amount') THEN
        ALTER TABLE coupons RENAME COLUMN min_order_amount TO min_order_value;
    END IF;

    -- Rename max_discount_amount to max_discount if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coupons' AND column_name = 'max_discount_amount') THEN
        ALTER TABLE coupons RENAME COLUMN max_discount_amount TO max_discount;
    END IF;

    -- Rename valid_until to valid_to if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coupons' AND column_name = 'valid_until') THEN
        ALTER TABLE coupons RENAME COLUMN valid_until TO valid_to;
    END IF;

    -- Rename usage_count to times_used if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coupons' AND column_name = 'usage_count') THEN
        ALTER TABLE coupons RENAME COLUMN usage_count TO times_used;
    END IF;
END $$;

-- 2. Clean up discount_type data before applying constraint
-- Update existing 'percent' to 'percentage'
UPDATE coupons SET discount_type = 'percentage' WHERE discount_type = 'percent';
-- Update anything that isn't valid to a default (percentage or fixed)
UPDATE coupons SET discount_type = 'percentage' WHERE discount_type NOT IN ('percentage', 'fixed');

-- 3. Update the constraint
ALTER TABLE coupons DROP CONSTRAINT IF EXISTS coupons_discount_type_check;
ALTER TABLE coupons ADD CONSTRAINT coupons_discount_type_check CHECK (discount_type IN ('percentage', 'fixed'));

-- 4. Add missing columns with defaults if they don't exist
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS min_order_value DECIMAL(10,2) DEFAULT 0;
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS max_discount DECIMAL(10,2);
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS times_used INTEGER DEFAULT 0;

-- 5. Add or replace the RPC function
CREATE OR REPLACE FUNCTION increment_coupon_usage(coupon_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE coupons
  SET times_used = times_used + 1
  WHERE id = coupon_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Ensure RLS is active and correct
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read active coupons" ON coupons;
CREATE POLICY "Anyone can read active coupons"
  ON coupons FOR SELECT
  USING (is_active = TRUE AND valid_from <= NOW() AND (valid_to IS NULL OR valid_to >= NOW()));

DROP POLICY IF EXISTS "Admin full access" ON coupons;
CREATE POLICY "Admin full access"
  ON coupons FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Final check
SELECT id, code, discount_type, min_order_value, times_used FROM coupons LIMIT 5;
