-- =====================================================
-- COUPONS TABLE SETUP
-- =====================================================
-- Run this in Supabase SQL Editor to enable coupon functionality

-- Create coupons table
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL CHECK (discount_value > 0),
    min_order_value DECIMAL(10,2) DEFAULT 0,
    max_discount DECIMAL(10,2),
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    usage_limit INTEGER,
    times_used INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- Create policy for anyone to read active coupons
CREATE POLICY "Anyone can view active coupons" 
ON public.coupons 
FOR SELECT 
USING (is_active = TRUE);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_coupons_code ON public.coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_active ON public.coupons(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_coupons_valid_dates ON public.coupons(valid_from, valid_to);

-- Insert sample coupons for testing
INSERT INTO public.coupons (code, discount_type, discount_value, min_order_value, max_discount, valid_from, valid_to, is_active, usage_limit) VALUES
    ('WELCOME10', 'percentage', 10, 500, 100, NOW(), NOW() + INTERVAL '30 days', TRUE, NULL),
    ('SAVE50', 'fixed', 50, 200, NULL, NOW(), NOW() + INTERVAL '30 days', TRUE, NULL),
    ('FIRST20', 'percentage', 20, 1000, 200, NOW(), NOW() + INTERVAL '30 days', TRUE, 100),
    ('BULK15', 'percentage', 15, 2000, 500, NOW(), NOW() + INTERVAL '30 days', TRUE, NULL),
    ('FLAT100', 'fixed', 100, 1500, NULL, NOW(), NOW() + INTERVAL '30 days', TRUE, 50)
ON CONFLICT (code) DO NOTHING;

-- ✅ COUPONS TABLE READY!
-- Test coupons:
-- - WELCOME10: 10% off (min ₹500, max ₹100 discount)
-- - SAVE50: ₹50 flat off (min ₹200)
-- - FIRST20: 20% off (min ₹1000, max ₹200 discount, limited to 100 uses)
-- - BULK15: 15% off (min ₹2000, max ₹500 discount)
-- - FLAT100: ₹100 flat off (min ₹1500, limited to 50 uses)
