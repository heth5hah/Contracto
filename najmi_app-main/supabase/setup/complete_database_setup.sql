-- =====================================================
-- CONTRACTO APP - COMPLETE DATABASE SETUP
-- =====================================================
-- Run this script in your Supabase SQL Editor
-- This will create all necessary tables, policies, and functions

-- =====================================================
-- 1. USERS TABLE
-- =====================================================
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

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policies for users table
CREATE POLICY "Users can view their own data" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own data" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Anyone can insert during registration" ON public.users
    FOR INSERT WITH CHECK (true);

-- =====================================================
-- 2. CATEGORIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active categories" ON public.categories
    FOR SELECT USING (is_active = TRUE);

-- =====================================================
-- 3. BRANDS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active brands" ON public.brands
    FOR SELECT USING (is_active = TRUE);

-- =====================================================
-- 4. PRODUCTS TABLE
-- =====================================================
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

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active products" ON public.products
    FOR SELECT USING (is_active = TRUE);

-- =====================================================
-- 5. ORDERS TABLE
-- =====================================================
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

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own orders" ON public.orders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create orders" ON public.orders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- 6. QUOTATIONS TABLE
-- =====================================================
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

ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own quotations" ON public.quotations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create quotations" ON public.quotations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- 7. ADDRESSES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    label TEXT DEFAULT 'Home',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own addresses" ON public.addresses
    FOR ALL USING (auth.uid() = user_id);

-- =====================================================
-- 8. ENQUIRIES TABLE
-- =====================================================
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

ALTER TABLE public.enquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own enquiries" ON public.enquiries
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can create enquiries" ON public.enquiries
    FOR INSERT WITH CHECK (true);

-- =====================================================
-- 9. INSERT SAMPLE DATA
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

-- Sample Products (using brand IDs)
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
) 
SELECT 
    'LED Bulb 9W',
    'Lighting',
    b.id,
    'Energy efficient LED bulb with 9W power consumption',
    250.00,
    199.00,
    20.40,
    100,
    true,
    ARRAY['https://via.placeholder.com/400']
FROM public.brands b WHERE b.name = 'Philips'
ON CONFLICT DO NOTHING;

-- =====================================================
-- 10. CREATE INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_brand ON public.products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_quotations_user ON public.quotations(user_id);

-- =====================================================
-- 11. CREATE UPDATED_AT TRIGGER FUNCTION
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_quotations_updated_at BEFORE UPDATE ON public.quotations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- SETUP COMPLETE!
-- =====================================================
-- Your database is now ready for the Contracto app
