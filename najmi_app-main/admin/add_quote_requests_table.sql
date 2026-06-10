-- Add Quote Requests Table - Updated for existing schema
-- This script adds new tables for the enhanced quote request system while preserving existing data

-- Create quote_requests table for the new system
CREATE TABLE IF NOT EXISTS public.quote_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    category TEXT,
    brand_id UUID REFERENCES public.brands(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'quoted', 'accepted', 'rejected', 'expired')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create quote_request_items table for quality options with quantities
CREATE TABLE IF NOT EXISTS public.quote_request_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    quote_request_id UUID REFERENCES public.quote_requests(id) ON DELETE CASCADE,
    quality_option_id TEXT,
    quality_option_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit TEXT DEFAULT 'units',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create quotes table for admin responses (different from existing quotations table)
CREATE TABLE IF NOT EXISTS public.quotes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    quote_request_id UUID REFERENCES public.quote_requests(id) ON DELETE CASCADE,
    admin_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
    subtotal DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    validity_days INTEGER DEFAULT 7,
    payment_terms TEXT,
    additional_notes TEXT,
    bank_name TEXT,
    account_number TEXT,
    ifsc_code TEXT,
    upi_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create quote_items table for individual item pricing
CREATE TABLE IF NOT EXISTS public.quote_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    quote_id UUID REFERENCES public.quotes(id) ON DELETE CASCADE,
    quality_option_id TEXT,
    quality_option_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit TEXT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_quote_requests_user_id ON public.quote_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_quote_requests_status ON public.quote_requests(status);
CREATE INDEX IF NOT EXISTS idx_quote_requests_created_at ON public.quote_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_quote_request_items_quote_request_id ON public.quote_request_items(quote_request_id);
CREATE INDEX IF NOT EXISTS idx_quotes_quote_request_id ON public.quotes(quote_request_id);
CREATE INDEX IF NOT EXISTS idx_quotes_status ON public.quotes(status);
CREATE INDEX IF NOT EXISTS idx_quote_items_quote_id ON public.quote_items(quote_id);

-- Enable Row Level Security
ALTER TABLE public.quote_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quote_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quote_items ENABLE ROW LEVEL SECURITY;

-- Create policies for quote_requests
CREATE POLICY "Users can view their own quote requests" ON public.quote_requests
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own quote requests" ON public.quote_requests
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own quote requests" ON public.quote_requests
    FOR UPDATE USING (auth.uid() = user_id);

-- Admin policies (users with admin role can view all)
CREATE POLICY "Admins can view all quote requests" ON public.quote_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can update all quote requests" ON public.quote_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Policies for quote_request_items
CREATE POLICY "Users can view their own quote request items" ON public.quote_request_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quote_requests 
            WHERE id = quote_request_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert their own quote request items" ON public.quote_request_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.quote_requests 
            WHERE id = quote_request_id AND user_id = auth.uid()
        )
    );

-- Admin policies for quote_request_items
CREATE POLICY "Admins can view all quote request items" ON public.quote_request_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Policies for quotes
CREATE POLICY "Users can view quotes for their requests" ON public.quotes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quote_requests 
            WHERE id = quote_request_id AND user_id = auth.uid()
        )
    );

-- Admin policies for quotes
CREATE POLICY "Admins can view all quotes" ON public.quotes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can insert quotes" ON public.quotes
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can update quotes" ON public.quotes
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Policies for quote_items
CREATE POLICY "Users can view quote items for their quotes" ON public.quote_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.quotes q
            JOIN public.quote_requests qr ON q.quote_request_id = qr.id
            WHERE q.id = quote_id AND qr.user_id = auth.uid()
        )
    );

-- Admin policies for quote_items
CREATE POLICY "Admins can view all quote items" ON public.quote_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can insert quote items" ON public.quote_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Create function to update updated_at timestamp (if it doesn't exist)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_quote_requests_updated_at 
    BEFORE UPDATE ON public.quote_requests 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_quotes_updated_at 
    BEFORE UPDATE ON public.quotes 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Add comment to distinguish from existing quotations table
COMMENT ON TABLE public.quote_requests IS 'New enhanced quote request system - separate from existing quotations table';
COMMENT ON TABLE public.quotes IS 'Admin-generated quotes in response to quote requests';
COMMENT ON TABLE public.quotations IS 'Existing basic quotations table - preserved for backward compatibility';

-- Optional: Add a migration flag to track that this has been run
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO public.schema_migrations (version) VALUES ('quote_requests_v1') 
ON CONFLICT (version) DO NOTHING;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Quote request tables created successfully!';
    RAISE NOTICE 'Existing quotations table preserved for backward compatibility.';
    RAISE NOTICE 'New system uses quote_requests, quotes, and related tables.';
END $$;
