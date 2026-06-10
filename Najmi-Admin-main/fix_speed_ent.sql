-- =============================================================================
-- FIX 5 LAKH BUG FOR THE LATEST USER (SPEED ENT)
-- This fixes the existing wrong record, but the code fix above prevents it
-- from ever happening again for future signups.
-- =============================================================================

UPDATE public.business_credit_accounts
SET 
  credit_limit = 0,
  available_credit = 0,
  status = 'pending',
  updated_at = NOW()
WHERE 
  credit_limit = 500000 
  AND used_credit = 0
  AND user_id IN (
    SELECT id FROM public.users WHERE company_name ILIKE '%Speed%' OR email ILIKE '%minispeed%'
  );

-- Verify
SELECT u.name, u.company_name, u.email, b.credit_limit, b.status
FROM public.users u
JOIN public.business_credit_accounts b ON u.id = b.user_id
WHERE u.company_name ILIKE '%Speed%' OR u.email ILIKE '%minispeed%';
