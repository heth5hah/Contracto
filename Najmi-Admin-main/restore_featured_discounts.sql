-- =============================================================================
-- RESTORE ~31% discount on featured products
--
-- Step 1: Run the SELECT below to see current state of featured products
-- Step 2: Pick the right UPDATE approach and run it
-- =============================================================================

-- STEP 1 ─ Preview current state of featured products
SELECT
  p.product_name,
  p.mrp,
  p.final_price                                                AS current_final_price,
  p.discount_percent                                           AS current_discount_pct,
  -- What price looks like at exactly 31% off MRP
  ROUND(CAST(p.mrp * 0.69 AS numeric), 2)                     AS price_at_31pct,
  -- What price would be if we reverse a 2% admin discount
  ROUND(CAST(p.final_price / 0.98 AS numeric), 2)             AS reversed_2pct_price,
  ROUND(CAST(
    (1 - (p.final_price / 0.98) / NULLIF(p.mrp, 0)) * 100
  AS numeric), 2)                                             AS reversed_2pct_discount
FROM products p
JOIN featured_products fp ON fp.product_id = p.id
WHERE fp.is_active = true
  AND p.is_active  = true
ORDER BY p.product_name;


-- =============================================================================
-- OPTION A ─ If the 2% was already reverted but featured products still show
--            wrong %, manually set them to 31% of MRP.
--            Uncomment and run this block:
-- =============================================================================

-- UPDATE products p
-- SET
--   final_price      = ROUND(CAST(p.mrp * 0.69 AS numeric), 2),  -- 31% off MRP
--   discount_percent = 31,
--   updated_at       = NOW()
-- FROM featured_products fp
-- WHERE fp.product_id = p.id
--   AND fp.is_active  = true
--   AND p.is_active   = true
--   AND p.mrp IS NOT NULL;


-- =============================================================================
-- OPTION B ─ If the 2% admin discount was NOT yet reversed on featured products
--            (discount_percent still shows 2), reverse it mathematically:
-- =============================================================================

-- UPDATE products p
-- SET
--   final_price      = ROUND(CAST(p.final_price / 0.98 AS numeric), 2),
--   discount_percent = GREATEST(0, ROUND(CAST(
--                        (1 - (p.final_price / 0.98) / NULLIF(p.mrp, 0)) * 100
--                      AS numeric), 2)),
--   updated_at       = NOW()
-- FROM featured_products fp
-- WHERE fp.product_id = p.id
--   AND fp.is_active  = true
--   AND p.is_active   = true
--   AND p.discount_percent = 2
--   AND p.final_price IS NOT NULL
--   AND p.mrp IS NOT NULL;
