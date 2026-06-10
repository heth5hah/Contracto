-- Business Credit Feature Database Schema
-- This creates tables for managing ₹5,00,000 credit limit for Business Accounts only

-- =====================================================
-- 1. BUSINESS CREDIT ACCOUNTS
-- =====================================================
CREATE TABLE IF NOT EXISTS public.business_credit_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    credit_limit DECIMAL(10,2) DEFAULT 500000.00, -- ₹5,00,000 default limit
    available_credit DECIMAL(10,2) DEFAULT 500000.00,
    used_credit DECIMAL(10,2) DEFAULT 0.00,
    kyc_status TEXT DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'approved', 'rejected')),
    kyc_approved_at TIMESTAMPTZ,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- =====================================================
-- 2. CREDIT USAGE (Transactions)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.credit_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_account_id UUID NOT NULL REFERENCES public.business_credit_accounts(id) ON DELETE CASCADE,
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    quote_request_id UUID REFERENCES public.quote_requests(id) ON DELETE SET NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('debit', 'credit', 'payment', 'adjustment')),
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    balance_after DECIMAL(10,2) NOT NULL, -- Available credit after this transaction
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 3. BILLING CYCLES
-- =====================================================
CREATE TABLE IF NOT EXISTS public.billing_cycles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_account_id UUID NOT NULL REFERENCES public.business_credit_accounts(id) ON DELETE CASCADE,
    cycle_start_date DATE NOT NULL,
    cycle_end_date DATE NOT NULL,
    due_date DATE NOT NULL,
    opening_balance DECIMAL(10,2) DEFAULT 0.00,
    total_charges DECIMAL(10,2) DEFAULT 0.00, -- Total credit used in this cycle
    total_payments DECIMAL(10,2) DEFAULT 0.00, -- Total payments made
    outstanding_amount DECIMAL(10,2) DEFAULT 0.00,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed', 'overdue')),
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 4. CREDIT PAYMENTS
-- =====================================================
CREATE TABLE IF NOT EXISTS public.credit_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_account_id UUID NOT NULL REFERENCES public.business_credit_accounts(id) ON DELETE CASCADE,
    billing_cycle_id UUID REFERENCES public.billing_cycles(id) ON DELETE SET NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('online', 'bank_transfer', 'cheque', 'other')),
    amount DECIMAL(10,2) NOT NULL,
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    transaction_id TEXT,
    payment_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 5. CREDIT STATEMENTS (Read-only view for history)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.credit_statements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_account_id UUID NOT NULL REFERENCES public.business_credit_accounts(id) ON DELETE CASCADE,
    statement_period_start DATE NOT NULL,
    statement_period_end DATE NOT NULL,
    opening_balance DECIMAL(10,2) NOT NULL,
    closing_balance DECIMAL(10,2) NOT NULL,
    total_debits DECIMAL(10,2) DEFAULT 0.00,
    total_credits DECIMAL(10,2) DEFAULT 0.00,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(credit_account_id, statement_period_start, statement_period_end)
);

-- =====================================================
-- INDEXES for Performance
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_credit_accounts_user_id ON public.business_credit_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_accounts_status ON public.business_credit_accounts(status);
CREATE INDEX IF NOT EXISTS idx_credit_usage_account_id ON public.credit_usage(credit_account_id);
CREATE INDEX IF NOT EXISTS idx_credit_usage_created_at ON public.credit_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_credit_usage_order_id ON public.credit_usage(order_id);
CREATE INDEX IF NOT EXISTS idx_billing_cycles_account_id ON public.billing_cycles(credit_account_id);
CREATE INDEX IF NOT EXISTS idx_billing_cycles_status ON public.billing_cycles(status);
CREATE INDEX IF NOT EXISTS idx_billing_cycles_due_date ON public.billing_cycles(due_date);
CREATE INDEX IF NOT EXISTS idx_credit_payments_account_id ON public.credit_payments(credit_account_id);
CREATE INDEX IF NOT EXISTS idx_credit_payments_status ON public.credit_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_credit_statements_account_id ON public.credit_statements(credit_account_id);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================
ALTER TABLE public.business_credit_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_statements ENABLE ROW LEVEL SECURITY;

-- Policies for business_credit_accounts
CREATE POLICY "Users can view their own credit account" ON public.business_credit_accounts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.id = business_credit_accounts.user_id
            AND users.user_type = 'company' -- Only for business accounts
        )
    );

CREATE POLICY "Users can update their own credit account" ON public.business_credit_accounts
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.id = business_credit_accounts.user_id
            AND users.user_type = 'company'
        )
    );

-- Policies for credit_usage
CREATE POLICY "Users can view their own credit usage" ON public.credit_usage
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.business_credit_accounts bca
            JOIN public.users u ON u.id = bca.user_id
            WHERE bca.id = credit_usage.credit_account_id
            AND u.id = auth.uid()
            AND u.user_type = 'company'
        )
    );

CREATE POLICY "System can insert credit usage" ON public.credit_usage
    FOR INSERT WITH CHECK (true); -- System inserts via service

-- Policies for billing_cycles
CREATE POLICY "Users can view their own billing cycles" ON public.billing_cycles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.business_credit_accounts bca
            JOIN public.users u ON u.id = bca.user_id
            WHERE bca.id = billing_cycles.credit_account_id
            AND u.id = auth.uid()
            AND u.user_type = 'company'
        )
    );

-- Policies for credit_payments
CREATE POLICY "Users can view their own credit payments" ON public.credit_payments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.business_credit_accounts bca
            JOIN public.users u ON u.id = bca.user_id
            WHERE bca.id = credit_payments.credit_account_id
            AND u.id = auth.uid()
            AND u.user_type = 'company'
        )
    );

CREATE POLICY "Users can insert their own credit payments" ON public.credit_payments
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.business_credit_accounts bca
            JOIN public.users u ON u.id = bca.user_id
            WHERE bca.id = credit_payments.credit_account_id
            AND u.id = auth.uid()
            AND u.user_type = 'company'
        )
    );

-- Policies for credit_statements
CREATE POLICY "Users can view their own credit statements" ON public.credit_statements
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.business_credit_accounts bca
            JOIN public.users u ON u.id = bca.user_id
            WHERE bca.id = credit_statements.credit_account_id
            AND u.id = auth.uid()
            AND u.user_type = 'company'
        )
    );

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_business_credit_accounts_updated_at 
    BEFORE UPDATE ON public.business_credit_accounts 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_billing_cycles_updated_at 
    BEFORE UPDATE ON public.billing_cycles 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_credit_payments_updated_at 
    BEFORE UPDATE ON public.credit_payments 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to automatically create credit account for business users
CREATE OR REPLACE FUNCTION public.create_business_credit_account()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create credit account for company users
    IF NEW.user_type = 'company' THEN
        INSERT INTO public.business_credit_accounts (user_id, credit_limit, available_credit)
        VALUES (NEW.id, 500000.00, 500000.00)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-create credit account when business user is created
CREATE TRIGGER create_credit_account_on_user_creation
    AFTER INSERT ON public.users
    FOR EACH ROW
    WHEN (NEW.user_type = 'company')
    EXECUTE FUNCTION public.create_business_credit_account();

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
GRANT ALL ON public.business_credit_accounts TO authenticated;
GRANT ALL ON public.credit_usage TO authenticated;
GRANT ALL ON public.billing_cycles TO authenticated;
GRANT ALL ON public.credit_payments TO authenticated;
GRANT ALL ON public.credit_statements TO authenticated;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE 'Business Credit tables created successfully!';
    RAISE NOTICE 'Credit limit: ₹5,00,000 for Business Accounts only';
END $$;

