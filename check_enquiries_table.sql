-- Check existing enquiries table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'enquiries'
ORDER BY ordinal_position;
