-- ============================================================================
-- COMPLETE RETURN FEATURE MIGRATION
-- ============================================================================
-- This file combines all three migration files in the correct order:
-- 1. Return Policy Settings
-- 2. Returns Tables
-- 3. Validation Functions
-- ============================================================================
-- Run this entire file in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- PART 1: RETURN POLICY SETTINGS
-- ============================================================================

-- 1. Create settings table if not exists (stores key-value configurations)
CREATE TABLE IF NOT EXISTS public.settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,
  value jsonb NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 2. Enable RLS on settings table
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS policies for settings (admin-only write, public read for app)
DO $$
BEGIN
    -- Allow anyone to read settings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'settings' AND policyname = 'Anyone can read settings') THEN
        CREATE POLICY "Anyone can read settings" ON public.settings
            FOR SELECT USING (true);
    END IF;

    -- Only authenticated users can update settings (admin check can be added)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'settings' AND policyname = 'Authenticated users can update settings') THEN
        CREATE POLICY "Authenticated users can update settings" ON public.settings
            FOR UPDATE USING (auth.uid() IS NOT NULL);
    END IF;

    -- Only authenticated users can insert settings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'settings' AND policyname = 'Authenticated users can insert settings') THEN
        CREATE POLICY "Authenticated users can insert settings" ON public.settings
            FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
    END IF;
END $$;

-- 4. Insert default return policy settings
INSERT INTO public.settings (key, value, description)
VALUES (
  'return_policy',
  '{"returns_enabled": true, "return_window_days": 7}'::jsonb,
  'Return policy configuration: enable/disable returns and set return window in days'
)
ON CONFLICT (key) DO NOTHING;

-- 5. Create function to update settings updated_at timestamp
CREATE OR REPLACE FUNCTION update_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create trigger for updated_at
DROP TRIGGER IF EXISTS settings_updated_at_trigger ON public.settings;
CREATE TRIGGER settings_updated_at_trigger
    BEFORE UPDATE ON public.settings
    FOR EACH ROW
    EXECUTE FUNCTION update_settings_updated_at();

-- ============================================================================
-- PART 2: RETURNS TABLES
-- ============================================================================

-- 1. Add delivered_at column to orders table
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivered_at timestamp with time zone;

-- 2. Create returns table
CREATE TABLE IF NOT EXISTS public.returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id),
  return_status text DEFAULT 'pending' CHECK (return_status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')),
  return_reason text,
  notes text,
  refund_amount numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 3. Create return_items table
CREATE TABLE IF NOT EXISTS public.return_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  return_id uuid NOT NULL REFERENCES public.returns(id) ON DELETE CASCADE,
  product_id text NOT NULL,
  product_name text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL,
  quality_option_name text,
  unit text,
  created_at timestamp with time zone DEFAULT now()
);

-- 4. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_returns_order_id ON public.returns(order_id);
CREATE INDEX IF NOT EXISTS idx_returns_user_id ON public.returns(user_id);
CREATE INDEX IF NOT EXISTS idx_returns_status ON public.returns(return_status);
CREATE INDEX IF NOT EXISTS idx_return_items_return_id ON public.return_items(return_id);

-- 5. Enable Row Level Security
ALTER TABLE public.returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_items ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for returns
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can view their own returns') THEN
        CREATE POLICY "Users can view their own returns" ON public.returns
            FOR SELECT USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can create their own returns') THEN
        CREATE POLICY "Users can create their own returns" ON public.returns
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'Users can update their own pending returns') THEN
        CREATE POLICY "Users can update their own pending returns" ON public.returns
            FOR UPDATE USING (auth.uid() = user_id AND return_status = 'pending');
    END IF;
END $$;

-- 7. Create RLS policies for return_items
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_items' AND policyname = 'Users can view their return items') THEN
        CREATE POLICY "Users can view their return items" ON public.return_items
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.returns 
                    WHERE returns.id = return_items.return_id 
                    AND returns.user_id = auth.uid()
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'return_items' AND policyname = 'Users can create return items') THEN
        CREATE POLICY "Users can create return items" ON public.return_items
            FOR INSERT WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.returns 
                    WHERE returns.id = return_items.return_id 
                    AND returns.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- 8. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_returns_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Create trigger for updated_at
DROP TRIGGER IF EXISTS returns_updated_at_trigger ON public.returns;
CREATE TRIGGER returns_updated_at_trigger
    BEFORE UPDATE ON public.returns
    FOR EACH ROW
    EXECUTE FUNCTION update_returns_updated_at();

-- ============================================================================
-- PART 3: VALIDATION FUNCTIONS
-- ============================================================================

-- 1. Create function to validate return eligibility
CREATE OR REPLACE FUNCTION validate_return_request(
  p_order_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_status text;
  v_delivered_at timestamptz;
  v_return_policy jsonb;
  v_returns_enabled boolean;
  v_return_window_days integer;
  v_days_since_delivery integer;
  v_is_valid boolean := true;
  v_error_message text;
BEGIN
  -- Fetch order details
  SELECT order_status, delivered_at
  INTO v_order_status, v_delivered_at
  FROM public.orders
  WHERE id = p_order_id AND user_id = p_user_id;

  -- Check if order exists and belongs to user
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'Order not found or does not belong to user'
    );
  END IF;

  -- Validate order is delivered
  IF v_order_status != 'delivered' THEN
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'Returns are only allowed for delivered orders'
    );
  END IF;

  -- Validate delivery date exists
  IF v_delivered_at IS NULL THEN
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'Order delivery date is missing. Cannot process return.'
    );
  END IF;

  -- Fetch return policy settings
  SELECT value INTO v_return_policy
  FROM public.settings
  WHERE key = 'return_policy';

  -- Use default if settings not found
  IF v_return_policy IS NULL THEN
    v_return_policy := '{"returns_enabled": true, "return_window_days": 7}'::jsonb;
  END IF;

  v_returns_enabled := COALESCE((v_return_policy->>'returns_enabled')::boolean, true);
  v_return_window_days := COALESCE((v_return_policy->>'return_window_days')::integer, 7);

  -- Validate returns are enabled
  IF NOT v_returns_enabled THEN
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'Returns are currently disabled'
    );
  END IF;

  -- Calculate days since delivery (timezone-safe)
  v_days_since_delivery := EXTRACT(DAY FROM (now() AT TIME ZONE 'UTC' - v_delivered_at AT TIME ZONE 'UTC'));

  -- Validate return window
  IF v_days_since_delivery > v_return_window_days THEN
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', format('Return period has expired. Returns are allowed within %s days from delivery.', v_return_window_days)
    );
  END IF;

  -- All validations passed
  RETURN jsonb_build_object(
    'is_valid', true,
    'remaining_days', GREATEST(0, v_return_window_days - v_days_since_delivery)
  );
END;
$$;

-- 2. Create trigger function to validate return requests before insert
CREATE OR REPLACE FUNCTION validate_return_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_validation_result jsonb;
BEGIN
  -- Validate the return request
  v_validation_result := validate_return_request(NEW.order_id, NEW.user_id);

  -- Check if validation failed
  IF NOT (v_validation_result->>'is_valid')::boolean THEN
    RAISE EXCEPTION '%', v_validation_result->>'error';
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Create trigger on returns table
DROP TRIGGER IF EXISTS validate_return_request_trigger ON public.returns;
CREATE TRIGGER validate_return_request_trigger
  BEFORE INSERT ON public.returns
  FOR EACH ROW
  EXECUTE FUNCTION validate_return_before_insert();

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Run these to verify everything was created correctly:

-- Check settings table
SELECT * FROM public.settings WHERE key = 'return_policy';

-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('returns', 'return_items', 'settings');

-- Check delivered_at column exists
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'orders' AND column_name = 'delivered_at';

-- Check functions exist
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('validate_return_request', 'validate_return_before_insert', 'update_returns_updated_at', 'update_settings_updated_at');

-- Check triggers exist
SELECT trigger_name, event_object_table FROM information_schema.triggers 
WHERE trigger_schema = 'public' 
AND trigger_name IN ('validate_return_request_trigger', 'returns_updated_at_trigger', 'settings_updated_at_trigger');

-- Check RLS policies
SELECT tablename, policyname FROM pg_policies 
WHERE tablename IN ('returns', 'return_items', 'settings')
ORDER BY tablename, policyname;

-- ============================================================================
-- MIGRATION COMPLETE!
-- ============================================================================
-- If all verification queries return expected results, the migration was successful.
-- You can now test the return feature in your mobile app and admin panel.
-- ============================================================================

