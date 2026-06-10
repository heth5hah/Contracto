-- Create a test coupon with proper UTC timestamps
-- Run this in Supabase SQL Editor to create a working test coupon

INSERT INTO coupons (
  code,
  description,
  discount_type,
  discount_value,
  min_order_value,
  max_discount,
  valid_from,
  valid_to,
  usage_limit,
  times_used,
  is_active
) VALUES (
  'TEST10',
  'Test coupon - 10% off',
  'percentage',
  10,
  100,
  50,
  NOW() - INTERVAL '1 hour',  -- Started 1 hour ago
  NOW() + INTERVAL '30 days', -- Valid for 30 days
  100,
  0,
  true
)
ON CONFLICT (code) 
DO UPDATE SET
  valid_from = NOW() - INTERVAL '1 hour',
  valid_to = NOW() + INTERVAL '30 days',
  is_active = true,
  times_used = 0;

-- Verify the coupon
SELECT 
  code,
  discount_type,
  discount_value,
  min_order_value,
  valid_from,
  valid_to,
  is_active,
  times_used,
  usage_limit
FROM coupons 
WHERE code = 'TEST10';
