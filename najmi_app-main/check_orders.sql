-- Run this in Supabase SQL editor to see what the payment_method actually is
SELECT id, payment_method, order_status, total_amount, created_at
FROM public.orders
ORDER BY created_at DESC
LIMIT 10;
