-- =============================================================================
-- REVERT 2% admin-panel discount from all active products
--
-- When the 2% discount was applied via the admin panel, the code ran:
--   new_final_price = old_final_price * 0.98   (discount on current selling price)
--   discount_percent = 2                        (overwriting original value)
--
-- To undo:
--   original_final_price  = current_final_price / 0.98
--   original_discount_pct = (1 - original_final_price / mrp) * 100
--
-- Run this in the Supabase SQL Editor.
-- =============================================================================

-- Preview first (SELECT) — run this to check before committing
SELECT
  id,
  product_name,
  mrp,
  final_price                                                           AS current_final_price,
  ROUND(CAST(final_price / 0.98 AS numeric), 2)                         AS restored_final_price,
  discount_percent                                                      AS current_discount_pct,
  GREATEST(0, ROUND(CAST(
    (1 - (final_price / 0.98) / NULLIF(mrp, 0)) * 100
  AS numeric), 2))                                                      AS restored_discount_pct
FROM products
WHERE is_active = true
  AND final_price IS NOT NULL
  AND discount_percent = 2
ORDER BY product_name;

-- =============================================================================
-- EXECUTE the revert (UPDATE) — uncomment and run after previewing above
-- =============================================================================

-- UPDATE products
-- SET
--   final_price      = ROUND(CAST(final_price / 0.98 AS numeric), 2),
--   discount_percent = GREATEST(0, ROUND(CAST(
--                        (1 - (final_price / 0.98) / NULLIF(mrp, 0)) * 100
--                      AS numeric), 2)),
--   updated_at       = NOW()
-- WHERE is_active = true
--   AND final_price IS NOT NULL
--   AND discount_percent = 2;
