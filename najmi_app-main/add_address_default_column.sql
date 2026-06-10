-- Add is_default column to addresses table
ALTER TABLE public.addresses 
ADD COLUMN IF NOT EXISTS is_default boolean DEFAULT false;

-- Create index for faster default address queries
CREATE INDEX IF NOT EXISTS idx_addresses_user_default 
ON public.addresses(user_id, is_default) 
WHERE is_default = true;

-- Ensure only one default address per user (optional constraint)
-- This creates a unique partial index that ensures only one address per user can have is_default = true
CREATE UNIQUE INDEX IF NOT EXISTS idx_addresses_one_default_per_user
ON public.addresses(user_id)
WHERE is_default = true;

-- Update existing addresses: set the most recent one as default if user has no default
DO $$
DECLARE
    user_record RECORD;
    latest_address_id uuid;
BEGIN
    -- For each user who has addresses but no default
    FOR user_record IN 
        SELECT DISTINCT user_id 
        FROM public.addresses 
        WHERE user_id NOT IN (
            SELECT user_id 
            FROM public.addresses 
            WHERE is_default = true
        )
    LOOP
        -- Get their most recent address
        SELECT id INTO latest_address_id
        FROM public.addresses
        WHERE user_id = user_record.user_id
        ORDER BY created_at DESC
        LIMIT 1;
        
        -- Set it as default
        IF latest_address_id IS NOT NULL THEN
            UPDATE public.addresses
            SET is_default = true
            WHERE id = latest_address_id;
        END IF;
    END LOOP;
END $$;
