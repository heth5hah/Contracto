-- Create featured products table
CREATE TABLE IF NOT EXISTS public.featured_products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create featured brands table
CREATE TABLE IF NOT EXISTS public.featured_brands (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID NOT NULL REFERENCES public.brands(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create image slides table for admin panel
CREATE TABLE IF NOT EXISTS public.image_slides (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT,
    description TEXT,
    image_url TEXT NOT NULL,
    link_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_featured_products_sort ON public.featured_products(sort_order, is_active);
CREATE INDEX IF NOT EXISTS idx_featured_brands_sort ON public.featured_brands(sort_order, is_active);
CREATE INDEX IF NOT EXISTS idx_image_slides_sort ON public.image_slides(sort_order, is_active);

-- Add RLS policies
ALTER TABLE public.featured_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.featured_brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_slides ENABLE ROW LEVEL SECURITY;

-- RLS policies for featured_products
CREATE POLICY "Featured products are viewable by everyone" ON public.featured_products
    FOR SELECT USING (is_active = true);

CREATE POLICY "Featured products are insertable by authenticated users" ON public.featured_products
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Featured products are updatable by authenticated users" ON public.featured_products
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Featured products are deletable by authenticated users" ON public.featured_products
    FOR DELETE USING (auth.role() = 'authenticated');

-- RLS policies for featured_brands
CREATE POLICY "Featured brands are viewable by everyone" ON public.featured_brands
    FOR SELECT USING (is_active = true);

CREATE POLICY "Featured brands are insertable by authenticated users" ON public.featured_brands
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Featured brands are updatable by authenticated users" ON public.featured_brands
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Featured brands are deletable by authenticated users" ON public.featured_brands
    FOR DELETE USING (auth.role() = 'authenticated');

-- RLS policies for image_slides
CREATE POLICY "Image slides are viewable by everyone" ON public.image_slides
    FOR SELECT USING (is_active = true);

CREATE POLICY "Image slides are insertable by authenticated users" ON public.image_slides
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Image slides are updatable by authenticated users" ON public.image_slides
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Image slides are deletable by authenticated users" ON public.image_slides
    FOR DELETE USING (auth.role() = 'authenticated');

-- Add updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers to update updated_at column
CREATE TRIGGER update_featured_products_updated_at 
    BEFORE UPDATE ON public.featured_products 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_featured_brands_updated_at 
    BEFORE UPDATE ON public.featured_brands 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_image_slides_updated_at 
    BEFORE UPDATE ON public.image_slides 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

