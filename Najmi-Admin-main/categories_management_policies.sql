-- =====================================================
-- CATEGORIES MANAGEMENT POLICIES FOR ADMIN PANEL
-- =====================================================
-- This SQL file provides RLS policies for admin access to categories
-- =====================================================

-- =====================================================
-- RLS POLICIES FOR CATEGORIES TABLE
-- =====================================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Admins can view all categories" ON public.categories;
DROP POLICY IF EXISTS "Admins can insert categories" ON public.categories;
DROP POLICY IF EXISTS "Admins can update categories" ON public.categories;
DROP POLICY IF EXISTS "Admins can delete categories" ON public.categories;
DROP POLICY IF EXISTS "Anyone can view categories" ON public.categories;
DROP POLICY IF EXISTS "Anyone can insert categories" ON public.categories;
DROP POLICY IF EXISTS "Anyone can update categories" ON public.categories;
DROP POLICY IF EXISTS "Anyone can delete categories" ON public.categories;

-- Policy: Admins can view ALL categories (including inactive ones)
CREATE POLICY "Admins can view all categories" ON public.categories
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can insert categories
CREATE POLICY "Admins can insert categories" ON public.categories
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can update categories
CREATE POLICY "Admins can update categories" ON public.categories
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Policy: Admins can delete categories
CREATE POLICY "Admins can delete categories" ON public.categories
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- =====================================================
-- INDEXES FOR BETTER PERFORMANCE
-- =====================================================

-- Index on categories.name for faster searches
CREATE INDEX IF NOT EXISTS idx_categories_name ON public.categories(name);

-- Index on categories.is_active for filtering
CREATE INDEX IF NOT EXISTS idx_categories_is_active ON public.categories(is_active);

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE 'Categories Management SQL setup completed successfully!';
    RAISE NOTICE 'RLS policies created for admin access to categories.';
    RAISE NOTICE 'Indexes created for better query performance.';
END $$;

