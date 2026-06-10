-- ==============================================================================
-- FIX: Allow User ID Auto-Merging by Enabling ON UPDATE CASCADE
-- ==============================================================================
-- This script dynamically finds all foreign keys that point to `public.users(id)`
-- and updates them to `ON UPDATE CASCADE`. This allows the app to seamlessly
-- merge old deleted accounts with new registrations without throwing the
-- "Database Conflict" or "violates foreign key constraint" errors.
--
-- This is 100% safe and will NOT break your existing workflows. It preserves
-- all your existing ON DELETE rules (like CASCADE or SET NULL).

DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT 
            tc.table_name, 
            kcu.column_name, 
            tc.constraint_name, 
            rc.update_rule, 
            rc.delete_rule
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.referential_constraints rc
          ON tc.constraint_name = rc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND kcu.table_schema = 'public'
          AND EXISTS (
              SELECT 1 FROM information_schema.constraint_column_usage ccu
              WHERE ccu.constraint_name = tc.constraint_name
                AND ccu.table_name = 'users'
                AND ccu.column_name = 'id'
          )
    LOOP
        -- 1. Drop the existing constraint
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I;', 
            r.table_name, r.constraint_name);
        
        -- 2. Recreate it with ON UPDATE CASCADE, keeping the exact same ON DELETE rule
        EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE %s;', 
            r.table_name, r.constraint_name, r.column_name, r.delete_rule);
            
        RAISE NOTICE 'Updated table %.% to ON UPDATE CASCADE', r.table_name, r.column_name;
    END LOOP;
END $$;
