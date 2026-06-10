-- Create credit accounts for existing business users
-- Run this after creating the business_credit_tables

-- Insert credit accounts for all existing company users who don't have one
INSERT INTO public.business_credit_accounts (user_id, credit_limit, available_credit, used_credit, kyc_status, status)
SELECT 
    u.id,
    500000.00 as credit_limit,
    500000.00 as available_credit,
    0.00 as used_credit,
    'pending' as kyc_status, -- Set to 'approved' manually after KYC verification
    'active' as status
FROM public.users u
WHERE u.user_type = 'company'
AND NOT EXISTS (
    SELECT 1 
    FROM public.business_credit_accounts bca 
    WHERE bca.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;

-- Success message
DO $$
DECLARE
    accounts_created INTEGER;
BEGIN
    SELECT COUNT(*) INTO accounts_created
    FROM public.business_credit_accounts;
    
    RAISE NOTICE 'Credit accounts created for existing business users!';
    RAISE NOTICE 'Total credit accounts: %', accounts_created;
    RAISE NOTICE 'Note: Update kyc_status to ''approved'' for users who have completed KYC';
END $$;

