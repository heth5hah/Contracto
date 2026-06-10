-- FIX: Remove NOT NULL constraints or add defaults for quotes table
-- This prevents errors when inserting quotes

-- Option 1: Make tax_amount nullable (RECOMMENDED)
ALTER TABLE quotes 
ALTER COLUMN tax_amount DROP NOT NULL;

-- Option 2: Set a default value for tax_amount
ALTER TABLE quotes 
ALTER COLUMN tax_amount SET DEFAULT 0;

-- Also ensure other numeric columns have defaults
ALTER TABLE quotes 
ALTER COLUMN subtotal SET DEFAULT 0;

ALTER TABLE quotes 
ALTER COLUMN total_amount SET DEFAULT 0;

ALTER TABLE quotes 
ALTER COLUMN transport_charges SET DEFAULT 0;

-- For quote_items table
ALTER TABLE quote_items
ALTER COLUMN quantity SET DEFAULT 1;

ALTER TABLE quote_items
ALTER COLUMN unit_price SET DEFAULT 0;

ALTER TABLE quote_items
ALTER COLUMN total_price SET DEFAULT 0;

-- Verify the changes
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'quotes'
AND column_name IN ('subtotal', 'tax_amount', 'total_amount', 'transport_charges')
ORDER BY column_name;

SELECT '✅ Quotes table constraints fixed!' as status;
