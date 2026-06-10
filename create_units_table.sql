-- =====================================================
-- Unit Management System - Database Migration
-- Run this SQL in Supabase SQL Editor
-- =====================================================

-- 1. Create units table
CREATE TABLE IF NOT EXISTS units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    symbol VARCHAR(10),
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create product_units junction table
CREATE TABLE IF NOT EXISTS product_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, unit_id)
);

-- 3. Seed default units for construction materials
INSERT INTO units (name, code, symbol, sort_order) VALUES
    ('Kilogram', 'Kg', 'kg', 1),
    ('Ton', 'Ton', 't', 2),
    ('Metric Ton', 'MT', 'MT', 3),
    ('Bag', 'Bag', 'bag', 4),
    ('Brass', 'Brass', 'brass', 5),
    ('Cubic Meter', 'CBM', 'm³', 6),
    ('Cubic Feet', 'CFT', 'ft³', 7),
    ('Liter', 'Ltr', 'L', 8),
    ('Piece', 'Pcs', 'pcs', 9),
    ('Feet', 'Ft', 'ft', 10),
    ('Meter', 'Mtr', 'm', 11),
    ('Running Meter', 'RM', 'rm', 12),
    ('Quintal', 'Qtl', 'qtl', 13),
    ('Bundle', 'Bdl', 'bdl', 14),
    ('Drum', 'Drum', 'drum', 15),
    ('Box', 'Box', 'box', 16),
    ('Number', 'Nos', 'nos', 17),
    ('Square Feet', 'SqFt', 'sq.ft', 18),
    ('Square Meter', 'SqM', 'sq.m', 19)
ON CONFLICT (code) DO NOTHING;

-- 4. Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_units_active ON units(is_active);
CREATE INDEX IF NOT EXISTS idx_units_sort ON units(sort_order);
CREATE INDEX IF NOT EXISTS idx_product_units_product ON product_units(product_id);
CREATE INDEX IF NOT EXISTS idx_product_units_unit ON product_units(unit_id);

-- 5. Enable RLS on units table
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_units ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for units (read access for all authenticated users)
CREATE POLICY "units_select_policy" ON units
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "units_insert_policy" ON units
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

CREATE POLICY "units_update_policy" ON units
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

CREATE POLICY "units_delete_policy" ON units
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- 7. RLS Policies for product_units
CREATE POLICY "product_units_select_policy" ON product_units
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "product_units_insert_policy" ON product_units
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

CREATE POLICY "product_units_update_policy" ON product_units
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

CREATE POLICY "product_units_delete_policy" ON product_units
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- 8. Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_units_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER units_updated_at_trigger
    BEFORE UPDATE ON units
    FOR EACH ROW
    EXECUTE FUNCTION update_units_updated_at();

-- 9. Verify the setup
SELECT 'Units table created successfully with ' || COUNT(*) || ' units' as status FROM units;
