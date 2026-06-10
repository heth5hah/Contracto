-- ============================================================================
-- ADMIN PANEL FEATURE ENHANCEMENT - DATABASE MIGRATION (FIXED)
-- ============================================================================
-- This migration adds comprehensive admin panel features while maintaining
-- 100% backward compatibility with the mobile app.
--
-- FIXED: Handles existing tables properly with ALTER TABLE instead of CREATE
-- ============================================================================

-- ============================================================================
-- PART 1: EXTEND EXISTING TABLES (Add Optional Columns)
-- ============================================================================

-- 1.1 Extend categories table
ALTER TABLE categories 
ADD COLUMN IF NOT EXISTS thumbnail_url TEXT,
ADD COLUMN IF NOT EXISTS detail_level TEXT DEFAULT 'short',
ADD COLUMN IF NOT EXISTS rules JSONB DEFAULT '{}'::jsonb;

-- Add check constraint if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'categories_detail_level_check') THEN
        ALTER TABLE categories ADD CONSTRAINT categories_detail_level_check CHECK (detail_level IN ('short', 'detailed'));
    END IF;
END $$;

-- 1.2 Extend brands table
ALTER TABLE brands 
ADD COLUMN IF NOT EXISTS about_text TEXT,
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS auto_resize_logo BOOLEAN DEFAULT true;

-- 1.3 Extend products table
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS enable_quote_request BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS admin_quote_note TEXT,
ADD COLUMN IF NOT EXISTS grid_layout TEXT DEFAULT '1x1';

-- Add check constraint if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'products_grid_layout_check') THEN
        ALTER TABLE products ADD CONSTRAINT products_grid_layout_check CHECK (grid_layout IN ('1x1', '1x3'));
    END IF;
END $$;

-- 1.4 Extend quote_requests table
ALTER TABLE quote_requests 
ADD COLUMN IF NOT EXISTS transport_charges NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS admin_status TEXT DEFAULT 'new';

-- Add check constraint if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'quote_requests_admin_status_check') THEN
        ALTER TABLE quote_requests ADD CONSTRAINT quote_requests_admin_status_check CHECK (admin_status IN ('new', 'processing', 'closed'));
    END IF;
END $$;

-- 1.5 Extend users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_business BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS pan_number TEXT,
ADD COLUMN IF NOT EXISTS business_name TEXT;

-- ============================================================================
-- PART 2: CREATE NEW TABLES (Only if they don't exist)
-- ============================================================================

-- 2.1 Category Rules Table
CREATE TABLE IF NOT EXISTS category_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  allowed_brands UUID[] DEFAULT '{}',
  allowed_products UUID[] DEFAULT '{}',
  visibility_rules JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.2 Brand Discounts Table
CREATE TABLE IF NOT EXISTS brand_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  min_quantity NUMERIC NOT NULL,
  max_quantity NUMERIC,
  discount_percent NUMERIC NOT NULL CHECK (discount_percent >= 0 AND discount_percent <= 100),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.3 Coupons Table
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('percent', 'fixed')),
  discount_value NUMERIC NOT NULL,
  min_order_amount NUMERIC DEFAULT 0,
  max_discount_amount NUMERIC,
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ,
  usage_limit INTEGER,
  usage_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.4 CMS Content Table
CREATE TABLE IF NOT EXISTS cms_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_key TEXT NOT NULL UNIQUE,
  content_value TEXT NOT NULL,
  content_type TEXT DEFAULT 'text' CHECK (content_type IN ('text', 'html', 'json')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.5 Tax Configuration Table
CREATE TABLE IF NOT EXISTS tax_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_key TEXT NOT NULL UNIQUE,
  config_value JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.6 Product-Brand Mapping Table (Many-to-Many)
CREATE TABLE IF NOT EXISTS product_brand_mapping (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  brand_id UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(product_id, brand_id)
);

-- ============================================================================
-- PART 3: INSERT DEFAULT DATA
-- ============================================================================

-- 3.1 Insert default CMS content
INSERT INTO cms_content (content_key, content_value, content_type) VALUES
('about_short', 'We are a leading supplier of construction materials with over 20 years of experience serving builders and contractors across India.', 'text'),
('about_long', '<p>Welcome to Najmi Construction Materials - your trusted partner in building excellence.</p><p>For over two decades, we have been at the forefront of supplying premium quality construction materials to builders, contractors, and homeowners across India. Our commitment to quality, reliability, and customer satisfaction has made us a preferred choice in the industry.</p><p>We offer an extensive range of products including TMT bars, cement, steel, plumbing materials, electrical fittings, and much more. Every product in our catalog is sourced from reputable manufacturers and undergoes strict quality checks.</p><p>Our team of experienced professionals is dedicated to providing personalized service, competitive pricing, and timely delivery. Whether you''re working on a small renovation or a large-scale construction project, we have the expertise and resources to meet your needs.</p><p>Choose Najmi Construction Materials for quality you can trust and service you can count on.</p>', 'html'),
('footer_helpline', '+91 1234567890', 'text'),
('footer_email', 'support@najmi.com', 'text'),
('footer_delivery_text', 'Fast delivery across India | Quality guaranteed', 'text')
ON CONFLICT (content_key) DO NOTHING;

-- 3.2 Insert default tax configuration
INSERT INTO tax_config (config_key, config_value) VALUES
('gst_rates', '{"default": 18, "categories": {"cement": 28, "steel": 18, "plumbing": 18}}'::jsonb),
('business_tax_rules', '{"require_pan": false, "require_gst": false, "validate_pan_format": true, "validate_gst_format": true}'::jsonb)
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================================
-- PART 4: CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_products_featured ON products(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_products_quote_enabled ON products(enable_quote_request) WHERE enable_quote_request = true;
CREATE INDEX IF NOT EXISTS idx_brands_featured ON brands(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_brand_discounts_brand ON brand_discounts(brand_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(is_active);
CREATE INDEX IF NOT EXISTS idx_product_brand_mapping_product ON product_brand_mapping(product_id);
CREATE INDEX IF NOT EXISTS idx_product_brand_mapping_brand ON product_brand_mapping(brand_id);
CREATE INDEX IF NOT EXISTS idx_category_rules_category ON category_rules(category_id);
CREATE INDEX IF NOT EXISTS idx_quote_requests_admin_status ON quote_requests(admin_status);
CREATE INDEX IF NOT EXISTS idx_users_business ON users(is_business) WHERE is_business = true;

-- ============================================================================
-- PART 5: SET UP RLS POLICIES (Skip if already exist)
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE category_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE brand_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE cms_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_brand_mapping ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate
DO $$ 
BEGIN
    -- Category Rules
    DROP POLICY IF EXISTS "Admin full access to category_rules" ON category_rules;
    CREATE POLICY "Admin full access to category_rules" ON category_rules FOR ALL TO authenticated USING (true);

    -- Brand Discounts
    DROP POLICY IF EXISTS "Admin full access to brand_discounts" ON brand_discounts;
    DROP POLICY IF EXISTS "Users can view active discounts" ON brand_discounts;
    CREATE POLICY "Admin full access to brand_discounts" ON brand_discounts FOR ALL TO authenticated USING (true);
    CREATE POLICY "Users can view active discounts" ON brand_discounts FOR SELECT TO authenticated USING (is_active = true);

    -- Coupons
    DROP POLICY IF EXISTS "Admin full access to coupons" ON coupons;
    DROP POLICY IF EXISTS "Users can view active coupons" ON coupons;
    CREATE POLICY "Admin full access to coupons" ON coupons FOR ALL TO authenticated USING (true);
    CREATE POLICY "Users can view active coupons" ON coupons FOR SELECT TO authenticated USING (is_active = true);

    -- CMS Content
    DROP POLICY IF EXISTS "Admin full access to cms_content" ON cms_content;
    DROP POLICY IF EXISTS "Users can view active cms_content" ON cms_content;
    CREATE POLICY "Admin full access to cms_content" ON cms_content FOR ALL TO authenticated USING (true);
    CREATE POLICY "Users can view active cms_content" ON cms_content FOR SELECT TO authenticated USING (is_active = true);

    -- Tax Config
    DROP POLICY IF EXISTS "Admin full access to tax_config" ON tax_config;
    DROP POLICY IF EXISTS "Users can view active tax_config" ON tax_config;
    CREATE POLICY "Admin full access to tax_config" ON tax_config FOR ALL TO authenticated USING (true);
    CREATE POLICY "Users can view active tax_config" ON tax_config FOR SELECT TO authenticated USING (is_active = true);

    -- Product-Brand Mapping
    DROP POLICY IF EXISTS "Admin full access to product_brand_mapping" ON product_brand_mapping;
    DROP POLICY IF EXISTS "Users can view product_brand_mapping" ON product_brand_mapping;
    CREATE POLICY "Admin full access to product_brand_mapping" ON product_brand_mapping FOR ALL TO authenticated USING (true);
    CREATE POLICY "Users can view product_brand_mapping" ON product_brand_mapping FOR SELECT TO authenticated USING (true);
END $$;

-- ============================================================================
-- PART 6: CREATE TRIGGERS FOR UPDATED_AT
-- ============================================================================

-- Function to update updated_at timestamp (create if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing triggers if they exist and recreate
DROP TRIGGER IF EXISTS update_category_rules_updated_at ON category_rules;
CREATE TRIGGER update_category_rules_updated_at BEFORE UPDATE ON category_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_brand_discounts_updated_at ON brand_discounts;
CREATE TRIGGER update_brand_discounts_updated_at BEFORE UPDATE ON brand_discounts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_coupons_updated_at ON coupons;
CREATE TRIGGER update_coupons_updated_at BEFORE UPDATE ON coupons FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_cms_content_updated_at ON cms_content;
CREATE TRIGGER update_cms_content_updated_at BEFORE UPDATE ON cms_content FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_tax_config_updated_at ON tax_config;
CREATE TRIGGER update_tax_config_updated_at BEFORE UPDATE ON tax_config FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

SELECT 
  'Migration completed successfully!' as status,
  NOW() as completed_at;
