-- FIX: Add missing columns to quotes table
-- Error: Could not find the 'transport_charges' column of 'quotes'

-- Step 1: Check current quotes table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'quotes'
ORDER BY ordinal_position;

-- Step 2: Add missing columns to quotes table
ALTER TABLE quotes 
ADD COLUMN IF NOT EXISTS transport_charges NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS subtotal NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_amount NUMERIC DEFAULT 0;

-- Step 3: Check quote_items table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'quote_items'
ORDER BY ordinal_position;

-- Step 4: Ensure quote_items has all required columns
ALTER TABLE quote_items
ADD COLUMN IF NOT EXISTS quality_option_id UUID,
ADD COLUMN IF NOT EXISTS quality_option_name TEXT,
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'units',
ADD COLUMN IF NOT EXISTS unit_price NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_price NUMERIC DEFAULT 0;

-- Step 5: Verify the changes
SELECT 
    'quotes' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'quotes'
UNION ALL
SELECT 
    'quote_items' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'quote_items'
ORDER BY table_name, column_name;

SELECT '✅ quotes and quote_items tables fixed!' as status;
