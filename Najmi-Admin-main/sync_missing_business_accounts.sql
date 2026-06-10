-- =============================================================================
-- SYNC BUSINESS ACCOUNTS
-- Run this in Supabase SQL Editor.
-- =============================================================================

-- Ensure ALL businesses have a credit account row so they appear in Business Billing
INSERT INTO public.business_credit_accounts (user_id, credit_limit, used_credit, available_credit, status)
SELECT 
    id as user_id, 
    0.00 as credit_limit, 
    0.00 as used_credit, 
    0.00 as available_credit, 
    'pending' as status
FROM public.users 
WHERE (user_type IN ('company', 'business') OR is_business = true)
AND id NOT IN (SELECT user_id FROM public.business_credit_accounts)
ON CONFLICT (user_id) DO NOTHING;

-- Also ensure any past credit usage is synced to the billing cycles if missing
-- (This creates an open billing cycle for anyone with used_credit > 0 who doesn't have one)
INSERT INTO public.billing_cycles (credit_account_id, cycle_start_date, cycle_end_date, due_date, opening_balance, outstanding_amount, status)
SELECT 
    b.id,
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '30 days',
    CURRENT_DATE + INTERVAL '15 days',
    b.used_credit,
    b.used_credit,
    'open'
FROM public.business_credit_accounts b
WHERE b.used_credit > 0 
AND b.id NOT IN (SELECT credit_account_id FROM public.billing_cycles WHERE status = 'open')
ON CONFLICT DO NOTHING;
