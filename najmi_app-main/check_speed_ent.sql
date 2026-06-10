SELECT u.id, u.email, u.company_name, bca.credit_limit, bca.used_credit, bca.available_credit
FROM users u
JOIN business_credit_accounts bca ON u.id = bca.user_id
WHERE u.company_name ILIKE '%Speed ENT%';

SELECT id, order_status, payment_method, payment_status, total_amount, created_at
FROM orders
WHERE user_id = (SELECT id FROM users WHERE company_name ILIKE '%Speed ENT%' LIMIT 1)
ORDER BY created_at DESC;

SELECT * FROM credit_usage
WHERE credit_account_id = (SELECT id FROM business_credit_accounts WHERE user_id = (SELECT id FROM users WHERE company_name ILIKE '%Speed ENT%' LIMIT 1))
ORDER BY created_at DESC;
