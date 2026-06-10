ALTER TABLE coupons ADD COLUMN IF NOT EXISTS applicable_users JSONB DEFAULT '[]'::jsonb;
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS applicable_products JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN coupons.applicable_users IS 'List of user emails this coupon is restricted to. Empty implies all.';
COMMENT ON COLUMN coupons.applicable_products IS 'List of product IDs this coupon is restricted to. Empty implies all.';
