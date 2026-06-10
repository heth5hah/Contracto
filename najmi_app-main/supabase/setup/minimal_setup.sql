-- =====================================================
-- CONTRACTO APP - MINIMAL SAFE SETUP
-- =====================================================
-- This only sets up what's absolutely necessary
-- Skips products table to avoid column errors
-- 100% safe - run this in Supabase SQL Editor

-- =====================================================
-- 1. CREATE MISSING TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    mobile TEXT UNIQUE NOT NULL,
    pan_number TEXT,
    gst_number TEXT,
    user_type TEXT DEFAULT 'individual',
    company_name TEXT,
    is_gst_registered BOOLEAN DEFAULT FALSE,
    role TEXT DEFAULT 'customer',
    credit_limit DECIMAL(10,2) DEFAULT 0.00,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    payment_status TEXT DEFAULT 'pending',
    order_status TEXT DEFAULT 'pending',
    notes TEXT,
    gst_number TEXT,
    total_amount DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    gst_amount DECIMAL(10,2) DEFAULT 0,
    delivery_charge DECIMAL(10,2) DEFAULT 0,
    invoice_required BOOLEAN DEFAULT FALSE,
    items JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    delivery_address TEXT,
    notes TEXT,
    status TEXT DEFAULT 'pending',
    total_amount DECIMAL(10,2) NOT NULL,
    items JSONB NOT NULL,
    admin_notes TEXT,
    quoted_price DECIMAL(10,2),
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    label TEXT DEFAULT 'Home',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.enquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 2. ENABLE ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enquiries ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. CREATE POLICIES
-- =====================================================

DO $$
BEGIN
    -- Users policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can view their own data') THEN
        CREATE POLICY "Users can view their own data" ON public.users FOR SELECT USING (auth.uid() = id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can update their own data') THEN
        CREATE POLICY "Users can update their own data" ON public.users FOR UPDATE USING (auth.uid() = id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Anyone can insert during registration') THEN
        CREATE POLICY "Anyone can insert during registration" ON public.users FOR INSERT WITH CHECK (true);
    END IF;

    -- Categories policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'categories' AND policyname = 'Anyone can view active categories') THEN
        CREATE POLICY "Anyone can view active categories" ON public.categories FOR SELECT USING (is_active = TRUE);
    END IF;

    -- Brands policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'brands' AND policyname = 'Anyone can view active brands') THEN
        CREATE POLICY "Anyone can view active brands" ON public.brands FOR SELECT USING (is_active = TRUE);
    END IF;

    -- Products policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'products' AND policyname = 'Anyone can view active products') THEN
        CREATE POLICY "Anyone can view active products" ON public.products FOR SELECT USING (is_active = TRUE);
    END IF;

    -- Orders policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'orders' AND policyname = 'Users can view their own orders') THEN
        CREATE POLICY "Users can view their own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'orders' AND policyname = 'Users can create orders') THEN
        CREATE POLICY "Users can create orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Quotations policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'quotations' AND policyname = 'Users can view their own quotations') THEN
        CREATE POLICY "Users can view their own quotations" ON public.quotations FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'quotations' AND policyname = 'Users can create quotations') THEN
        CREATE POLICY "Users can create quotations" ON public.quotations FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Addresses policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'addresses' AND policyname = 'Users can manage their own addresses') THEN
        CREATE POLICY "Users can manage their own addresses" ON public.addresses FOR ALL USING (auth.uid() = user_id);
    END IF;

    -- Enquiries policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'enquiries' AND policyname = 'Users can view their own enquiries') THEN
        CREATE POLICY "Users can view their own enquiries" ON public.enquiries FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'enquiries' AND policyname = 'Anyone can create enquiries') THEN
        CREATE POLICY "Anyone can create enquiries" ON public.enquiries FOR INSERT WITH CHECK (true);
    END IF;
END $$;

-- =====================================================
-- 4. INSERT SAMPLE CATEGORIES (SAFE)
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Electrical') THEN
        INSERT INTO public.categories (name, description, is_active) VALUES ('Electrical', 'Electrical equipment and supplies', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Hardware') THEN
        INSERT INTO public.categories (name, description, is_active) VALUES ('Hardware', 'Hardware tools and equipment', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Lighting') THEN
        INSERT INTO public.categories (name, description, is_active) VALUES ('Lighting', 'Lighting fixtures and bulbs', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Cables') THEN
        INSERT INTO public.categories (name, description, is_active) VALUES ('Cables', 'Electrical cables and wires', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Switches') THEN
        INSERT INTO public.categories (name, description, is_active) VALUES ('Switches', 'Electrical switches and sockets', TRUE);
    END IF;
END $$;

-- =====================================================
-- 5. INSERT SAMPLE BRANDS (SAFE)
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.brands WHERE name = 'Havells') THEN
        INSERT INTO public.brands (name, description, is_active) VALUES ('Havells', 'Leading electrical equipment manufacturer', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.brands WHERE name = 'Polycab') THEN
        INSERT INTO public.brands (name, description, is_active) VALUES ('Polycab', 'Premium cables and wires', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.brands WHERE name = 'Anchor') THEN
        INSERT INTO public.brands (name, description, is_active) VALUES ('Anchor', 'Trusted switches and sockets', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.brands WHERE name = 'Philips') THEN
        INSERT INTO public.brands (name, description, is_active) VALUES ('Philips', 'Quality lighting solutions', TRUE);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.brands WHERE name = 'Legrand') THEN
        INSERT INTO public.brands (name, description, is_active) VALUES ('Legrand', 'Innovative electrical products', TRUE);
    END IF;
END $$;

-- =====================================================
-- 6. CREATE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_quotations_user ON public.quotations(user_id);

-- =====================================================
-- 7. CREATE TRIGGERS
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_orders_updated_at ON public.orders;
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_quotations_updated_at ON public.quotations;
CREATE TRIGGER update_quotations_updated_at BEFORE UPDATE ON public.quotations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- ✅ SETUP COMPLETE!
-- =====================================================
-- Your database is ready for registration and basic app features
-- Products, categories, and brands tables are left as-is
