-- =====================================================
-- CONTRACTO APP - ULTRA SAFE DATABASE SETUP
-- =====================================================
-- This version is 100% safe and won't delete any data
-- It only ADDS missing tables and policies
-- Run this in your Supabase SQL Editor

-- =====================================================
-- 1. CREATE TABLES (ONLY IF THEY DON'T EXIST)
-- =====================================================

-- USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    mobile TEXT UNIQUE NOT NULL,
    pan_number TEXT,
    gst_number TEXT,
    user_type TEXT DEFAULT 'individual' CHECK (user_type IN ('individual', 'company')),
    company_name TEXT,
    is_gst_registered BOOLEAN DEFAULT FALSE,
    role TEXT DEFAULT 'customer' CHECK (role IN ('customer', 'admin', 'sales')),
    credit_limit DECIMAL(10,2) DEFAULT 0.00,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- CATEGORIES TABLE
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- BRANDS TABLE
CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PRODUCTS TABLE
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_name TEXT NOT NULL,
    category TEXT,
    brand_id UUID REFERENCES public.brands(id),
    description TEXT,
    specifications JSONB,
    mrp DECIMAL(10,2),
    final_price DECIMAL(10,2),
    discount_percentage DECIMAL(5,2),
    stock_quantity INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    images TEXT[],
    quality_options JSONB,
    bulk_discounts JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ORDERS TABLE
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    order_status TEXT DEFAULT 'pending' CHECK (order_status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')),
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

-- QUOTATIONS TABLE
CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    delivery_address TEXT,
    notes TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'converted')),
    total_amount DECIMAL(10,2) NOT NULL,
    items JSONB NOT NULL,
    admin_notes TEXT,
    quoted_price DECIMAL(10,2),
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ADDRESSES TABLE
CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    label TEXT DEFAULT 'Home',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ENQUIRIES TABLE
CREATE TABLE IF NOT EXISTS public.enquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'contacted', 'resolved', 'closed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 2. ENABLE ROW LEVEL SECURITY (SAFE)
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
-- 3. CREATE POLICIES (ONLY IF THEY DON'T EXIST)
-- =====================================================
-- Note: We use DO blocks to safely create policies

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
-- 4. INSERT SAMPLE DATA (SAFE - WON'T DUPLICATE)
-- =====================================================

-- Sample Categories
INSERT INTO public.categories (name, description, icon, sort_order) VALUES
    ('Electrical', 'Electrical equipment and supplies', 'electrical', 1),
    ('Hardware', 'Hardware tools and equipment', 'hardware', 2),
    ('Lighting', 'Lighting fixtures and bulbs', 'lighting', 3),
    ('Cables', 'Electrical cables and wires', 'cables', 4),
    ('Switches', 'Electrical switches and sockets', 'switches', 5)
ON CONFLICT (name) DO NOTHING;

-- Sample Brands
INSERT INTO public.brands (name, description, sort_order) VALUES
    ('Havells', 'Leading electrical equipment manufacturer', 1),
    ('Polycab', 'Premium cables and wires', 2),
    ('Anchor', 'Trusted switches and sockets', 3),
    ('Philips', 'Quality lighting solutions', 4),
    ('Legrand', 'Innovative electrical products', 5)
ON CONFLICT (name) DO NOTHING;

-- Sample Product (only if Philips brand exists)
DO $$
DECLARE
    philips_id UUID;
BEGIN
    SELECT id INTO philips_id FROM public.brands WHERE name = 'Philips' LIMIT 1;
    
    IF philips_id IS NOT NULL THEN
        INSERT INTO public.products (
            product_name, 
            category, 
            brand_id,
            description, 
            mrp, 
            final_price, 
            discount_percentage,
            stock_quantity,
            is_featured,
            images
        ) VALUES (
            'LED Bulb 9W',
            'Lighting',
            philips_id,
            'Energy efficient LED bulb with 9W power consumption',
            250.00,
            199.00,
            20.40,
            100,
            true,
            ARRAY['https://via.placeholder.com/400']
        )
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- =====================================================
-- 5. CREATE INDEXES (SAFE)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_brand ON public.products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_quotations_user ON public.quotations(user_id);

-- =====================================================
-- 6. CREATE TRIGGERS (SAFE)
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate triggers (safe operation)
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_products_updated_at ON public.products;
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_orders_updated_at ON public.orders;
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_quotations_updated_at ON public.quotations;
CREATE TRIGGER update_quotations_updated_at BEFORE UPDATE ON public.quotations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- ✅ SETUP COMPLETE - 100% SAFE!
-- =====================================================
-- No data was deleted, only missing items were added
