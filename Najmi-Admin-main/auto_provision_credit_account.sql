-- =============================================================================
-- AUTO-CREATE CREDIT ACCOUNTS ON UPDATE
-- Run this in Supabase SQL Editor.
-- =============================================================================

-- Create a trigger that automatically provisions a business_credit_account
-- if an admin manually upgrades an Individual to a Business via the portal.

CREATE OR REPLACE FUNCTION public.handle_user_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If user type changed to company/business, or is_business became true
  IF (NEW.user_type IN ('company', 'business') OR NEW.is_business = true) THEN
    INSERT INTO public.business_credit_accounts (
        user_id, credit_limit, used_credit, available_credit, status
    )
    VALUES (
        NEW.id, 0.00, 0.00, 0.00, 'pending'
    )
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_user_update ON public.users;

CREATE TRIGGER on_user_update
  AFTER UPDATE OF user_type, is_business ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_update();

-- And run the sync just to be safe for existing users
INSERT INTO public.business_credit_accounts (user_id, credit_limit, used_credit, available_credit, status)
SELECT 
    id as user_id, 0.00, 0.00, 0.00, 'pending'
FROM public.users 
WHERE (user_type IN ('company', 'business') OR is_business = true)
AND id NOT IN (SELECT user_id FROM public.business_credit_accounts)
ON CONFLICT (user_id) DO NOTHING;
