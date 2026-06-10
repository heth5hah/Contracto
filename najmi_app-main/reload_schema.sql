-- Run this script in your Supabase SQL Editor to force the API to recognize the new column
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_due_date timestamp with time zone;
ALTER TABLE public.quote_requests ADD COLUMN IF NOT EXISTS payment_due_date timestamp with time zone;

-- Force Supabase API (PostgREST) to reload its schema cache
NOTIFY pgrst, 'reload schema';
