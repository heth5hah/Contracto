-- =====================================================
-- CONTRACTO APP - ADAPTIVE SAFE SETUP
-- =====================================================
-- This script adapts to your existing database structure
-- It will ONLY add what's missing, never delete data
-- Run this in your Supabase SQL Editor

-- =====================================================
-- 1. ADD MISSING COLUMNS TO EXISTING TABLES (SAFE)
-- =====================================================

-- Add icon column to categories if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'categories' 
                   AND column_name = 'icon') THEN
        ALTER TABLE public.categories ADD COLUMN icon TEXT;
    END IF;
END $$;

-- Add sort_order to categories if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'categories' 
                   AND column_name = 'sort_order') THEN
        ALTER TABLE public.categories ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;
END $$;

-- Add sort_order to brands if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'brands' 
                   AND column_name = 'sort_order') THEN
        ALTER TABLE public.brands ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;
END $$;

-- =====================================================
-- 2. CREATE MISSING TABLES (IF THEY DON'T EXIST)
-- =====================================================

-- USERS TABLE
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

-- QUOTATIONS TABLE
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
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 3. ENABLE ROW LEVEL SECURITY (SAFE)
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
-- 4. CREATE POLICIES (ONLY IF THEY DON'T EXIST)
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
-- 5. INSERT SAMPLE DATA (SAFE - ADAPTS TO YOUR SCHEMA)
-- =====================================================

-- Sample Categories (only name, description, is_active)
INSERT INTO public.categories (name, description, is_active) VALUES
    ('Electrical', 'Electrical equipment and supplies', TRUE),
    ('Hardware', 'Hardware tools and equipment', TRUE),
    ('Lighting', 'Lighting fixtures and bulbs', TRUE),
    ('Cables', 'Electrical cables and wires', TRUE),
    ('Switches', 'Electrical switches and sockets', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Update icon and sort_order if columns exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'categories' 
               AND column_name = 'icon') THEN
        UPDATE public.categories SET icon = 'electrical', sort_order = 1 WHERE name = 'Electrical';
        UPDATE public.categories SET icon = 'hardware', sort_order = 2 WHERE name = 'Hardware';
        UPDATE public.categories SET icon = 'lighting', sort_order = 3 WHERE name = 'Lighting';
        UPDATE public.categories SET icon = 'cables', sort_order = 4 WHERE name = 'Cables';
        UPDATE public.categories SET icon = 'switches', sort_order = 5 WHERE name = 'Switches';
    END IF;
END $$;

-- Sample Brands
INSERT INTO public.brands (name, description, is_active) VALUES
    ('Havells', 'Leading electrical equipment manufacturer', TRUE),
    ('Polycab', 'Premium cables and wires', TRUE),
    ('Anchor', 'Trusted switches and sockets', TRUE),
    ('Philips', 'Quality lighting solutions', TRUE),
    ('Legrand', 'Innovative electrical products', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Update sort_order if column exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'brands' 
               AND column_name = 'sort_order') THEN
        UPDATE public.brands SET sort_order = 1 WHERE name = 'Havells';
        UPDATE public.brands SET sort_order = 2 WHERE name = 'Polycab';
        UPDATE public.brands SET sort_order = 3 WHERE name = 'Anchor';
        UPDATE public.brands SET sort_order = 4 WHERE name = 'Philips';
        UPDATE public.brands SET sort_order = 5 WHERE name = 'Legrand';
    END IF;
END $$;

-- Sample Product (only if Philips brand exists and products table exists)
DO $$
DECLARE
    philips_id UUID;
    products_exists BOOLEAN;
BEGIN
    -- Check if products table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'products'
    ) INTO products_exists;
    
    IF products_exists THEN
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
    END IF;
END $$;

-- =====================================================
-- 6. CREATE INDEXES (SAFE)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_brand ON public.products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_quotations_user ON public.quotations(user_id);

-- =====================================================
-- 7. CREATE TRIGGERS (SAFE)
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
-- ✅ SETUP COMPLETE!
-- =====================================================
-- Database is now ready and adapted to your existing structure
-- All existing data is preserved
