-- Migration: Add category hierarchy support
-- Description: Adds parent-child relationship support for categories

-- Add parent category reference
ALTER TABLE categories ADD COLUMN IF NOT EXISTS parent_category_id UUID REFERENCES categories(id) ON DELETE SET NULL;

-- Create index for parent category lookups
CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_category_id);

-- Add comment for documentation
COMMENT ON COLUMN categories.parent_category_id IS 'Reference to parent category for hierarchical category structure';
