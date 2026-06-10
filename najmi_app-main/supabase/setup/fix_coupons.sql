-- =====================================================
-- FIX COUPONS - Run this to ensure coupons work
-- =====================================================

-- First, let's drop the restrictive policy and create a more permissive one
DROP POLICY IF EXISTS "Anyone can view active coupons" ON public.coupons;

-- Create a policy that allows everyone to read all coupons (not just active ones for testing)
CREATE POLICY "Allow public read access to coupons" 
ON public.coupons 
FOR SELECT 
TO public
USING (true);

-- Delete existing coupons to avoid conflicts
DELETE FROM public.coupons WHERE code IN ('WELCOME10', 'SAVE50', 'FIRST20', 'BULK15', 'FLAT100');

-- Insert fresh coupons
INSERT INTO public.coupons (code, discount_type, discount_value, min_order_value, max_discount, valid_from, valid_to, is_active, usage_limit) VALUES
    ('WELCOME10', 'percentage', 10, 500, 100, NOW(), NOW() + INTERVAL '30 days', TRUE, NULL),
    ('SAVE50', 'fixed', 50, 200, NULL, NOW(), NOW() + INTERVAL '30 days', TRUE, NULL),
    ('FIRST20', 'percentage', 20, 1000, 200, NOW(), NOW() + INTERVAL '30 days', TRUE, 100),
    ('BULK15', 'percentage', 15, 2000, 500, NOW(), NOW() + INTERVAL '30 days', TRUE, NULL),
    ('FLAT100', 'fixed', 100, 1500, NULL, NOW(), NOW() + INTERVAL '30 days', TRUE, 50);

-- Verify coupons were inserted
SELECT code, discount_type, discount_value, min_order_value, is_active FROM public.coupons;

-- ✅ You should see 5 rows returned!
