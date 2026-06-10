CREATE OR REPLACE FUNCTION public.get_all_credit_usage_debug()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT json_agg(t) INTO v_result FROM (
    SELECT id, credit_account_id, transaction_type, amount, description, created_at, balance_after
    FROM public.credit_usage
    ORDER BY created_at DESC
  ) t;
  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_all_credit_usage_debug() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_credit_usage_debug() TO anon;
