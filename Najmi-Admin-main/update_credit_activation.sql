
-- SQL SCRIPT FOR DEDICATED CREDIT ACTIVATION CONTROL
-- This adds/ensures the status column exists and sets up security.

-- 1. Ensure the 'status' column exists in business_credit_accounts
-- and has a default value of 'active'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'business_credit_accounts' 
        AND column_name = 'status'
    ) THEN
        ALTER TABLE public.business_credit_accounts 
        ADD COLUMN status text DEFAULT 'active' CHECK (status IN ('active', 'inactive'));
        RAISE NOTICE 'Added status column to business_credit_accounts';
    END IF;
END $$;

-- 2. Update RLS Policies for business_credit_accounts
ALTER TABLE public.business_credit_accounts ENABLE ROW LEVEL SECURITY;

-- Drop old policies to prevent conflicts
DROP POLICY IF EXISTS "Admins can manage all credit accounts" ON public.business_credit_accounts;
DROP POLICY IF EXISTS "Users can view their own credit account" ON public.business_credit_accounts;

-- Allow users to see their own credit limit and status
CREATE POLICY "Users can view their own credit account" 
ON public.business_credit_accounts FOR SELECT 
TO authenticated
USING (auth.uid() = user_id);

-- Allow admins full control
CREATE POLICY "Admins can manage all credit accounts" 
ON public.business_credit_accounts FOR ALL 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND LOWER(role) = 'admin'
    )
);

-- 3. Grant proper permissions
GRANT ALL ON public.business_credit_accounts TO authenticated, service_role;
GRANT ALL ON public.credit_usage TO authenticated, service_role;
GRANT ALL ON public.billing_cycles TO authenticated, service_role;
GRANT ALL ON public.credit_payments TO authenticated, service_role;

RAISE NOTICE 'Credit activation security and schema verified successfully!';
