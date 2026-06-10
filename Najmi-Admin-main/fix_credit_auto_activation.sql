-- =============================================================================
-- FIX: Business credit accounts should NOT auto-activate on registration.
--
-- The `handle_user_profile` RPC currently creates business credit accounts
-- with status = 'active' and credit_limit = 500000. This needs to change:
--   → New accounts should have status = 'pending' (awaiting admin approval)
--   → credit_limit = 0, available_credit = 0
--   → Only when admin clicks "Activate Credit" does it become active
-- =============================================================================

-- STEP 1: Fix the existing "New Business" account that was auto-created
-- (Set to pending so admin must approve it)
-- Run this SELECT first to preview:

SELECT id, user_id, credit_limit, available_credit, status, created_at
FROM business_credit_accounts
WHERE status = 'active'
  AND used_credit = 0
ORDER BY created_at DESC;


-- STEP 2: Set all unused active business accounts to 'pending'
-- (Only affects accounts that have never been used — no harm to existing businesses)
-- Uncomment to run:

-- UPDATE business_credit_accounts
-- SET status = 'pending',
--     credit_limit = 0,
--     available_credit = 0
-- WHERE status = 'active'
--   AND used_credit = 0
--   AND credit_limit > 0;


-- STEP 3: Update the handle_user_profile function so NEW business users
-- get status='pending' instead of 'active', and credit_limit=0
--
-- ⚠️  IMPORTANT: You must check your actual function definition in Supabase
--     (Database → Functions → handle_user_profile) and change:
--
--     FROM:  'status': 'active', 'credit_limit': 500000, 'available_credit': 500000
--     TO:    'status': 'pending', 'credit_limit': 0, 'available_credit': 0
--
-- If you have a trigger that auto-creates credit accounts, update it similarly.
-- Look for: CREATE TRIGGER ... AFTER INSERT ON users ...

-- Example fix for the RPC (adjust to match your actual function):
/*
CREATE OR REPLACE FUNCTION handle_user_profile(
  p_user_id UUID,
  p_email TEXT,
  p_name TEXT,
  p_mobile TEXT,
  p_user_type TEXT DEFAULT 'individual',
  p_company_name TEXT DEFAULT NULL,
  p_gst_number TEXT DEFAULT NULL,
  p_pan_number TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- ... existing user insert/upsert logic ...

  -- Only create credit account for company users
  IF p_user_type = 'company' AND p_company_name IS NOT NULL THEN
    INSERT INTO business_credit_accounts (user_id, credit_limit, available_credit, used_credit, status)
    VALUES (p_user_id, 0, 0, 0, 'pending')     -- ← CHANGED: was 500000 / 'active'
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
END;
$$;
*/
