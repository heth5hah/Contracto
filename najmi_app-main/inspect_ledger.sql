-- =========================================================================
-- INSPECT LEDGER
-- Run this script in your Supabase SQL Editor and show me the output grid/results.
-- =========================================================================

SELECT 
  (SELECT COUNT(*) FROM public.credit_usage WHERE credit_account_id = '65e10686-3736-4c97-b73d-fc56adf36fcb') as total_rows,
  (SELECT COALESCE(SUM(amount), 0) FROM public.credit_usage WHERE credit_account_id = '65e10686-3736-4c97-b73d-fc56adf36fcb' AND LOWER(transaction_type) = 'debit') as debits_sum,
  (SELECT COALESCE(SUM(amount), 0) FROM public.credit_usage WHERE credit_account_id = '65e10686-3736-4c97-b73d-fc56adf36fcb' AND LOWER(transaction_type) != 'debit') as credits_sum;

-- Also inspect the individual rows to see what is mismatching
SELECT id, transaction_type, amount, description, balance_after, created_at
FROM public.credit_usage
WHERE credit_account_id = '65e10686-3736-4c97-b73d-fc56adf36fcb'
ORDER BY created_at DESC;
