-- Backend Validation Function for Return Requests
-- This function validates return requests at the database level
-- Run this migration on Supabase SQL Editor

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

-- 4. Grant execute permission on function (if needed)
-- GRANT EXECUTE ON FUNCTION validate_return_request(uuid, uuid) TO authenticated;

-- Verification query (optional)
-- SELECT validate_return_request('order-id-here', 'user-id-here');

