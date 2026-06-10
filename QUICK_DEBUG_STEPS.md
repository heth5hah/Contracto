# 🔍 Quick Debug Steps - Return Not Showing

## Issue
Return request exists in mobile app but not showing in admin panel order details.

## Step-by-Step Debug

### Step 1: Check Browser Console
1. Open admin panel in Edge
2. Press **F12** to open DevTools
3. Go to **Console** tab
4. Click **"View"** on the order that has the return
5. Look for these messages:
   - `FETCHING RETURNS FOR ORDER`
   - `Order ID: ...`
   - `Number of returns found: X`
   - Any error messages

### Step 2: Verify Return Exists in Database
Run this in Supabase SQL Editor:

```sql
-- Find the return request
SELECT 
    r.id,
    r.order_id,
    r.return_status,
    r.refund_amount,
    r.created_at,
    o.id as order_db_id,
    o.customer_name
FROM returns r
JOIN orders o ON o.id = r.order_id
WHERE o.customer_name ILIKE '%Prathamesh%'
ORDER BY r.created_at DESC;
```

This will show:
- The return request
- The order ID it's linked to
- Whether it exists

### Step 3: Check Order ID Match
The mobile app shows order ID as `51B4004E7735` (shortened), but the database uses full UUIDs.

Run this to find the full order ID:

```sql
-- Find order by customer name and date
SELECT 
    id,
    customer_name,
    order_status,
    created_at,
    SUBSTRING(id::text, 1, 12) as short_id
FROM orders
WHERE customer_name ILIKE '%Prathamesh%'
ORDER BY created_at DESC;
```

Compare the `short_id` with `51B4004E7735` to find the matching order.

### Step 4: Verify RLS Policies
Run this to check admin policies:

```sql
SELECT tablename, policyname 
FROM pg_policies 
WHERE tablename = 'returns'
AND policyname LIKE '%Admin%';
```

Should show:
- `Admins can view all returns`
- `Admins can update all returns`

### Step 5: Check Your Admin Role
```sql
SELECT id, email, role FROM users WHERE id = auth.uid();
```

Should show `role = 'admin'`

---

## Common Issues & Fixes

### Issue: "Number of returns found: 0"
**Possible causes:**
1. Order ID mismatch (mobile shows short ID, DB has full UUID)
2. Return linked to different order
3. RLS blocking access

**Fix:**
- Check console for the actual order ID being queried
- Verify return's `order_id` matches the order's `id` in database

### Issue: "Error loading returns: permission denied"
**Fix:**
- Run `fix_admin_returns_access.sql` again
- Verify your user role is 'admin'

### Issue: Returns exist but don't show
**Fix:**
- Hot reload admin panel (press `r` in terminal)
- Or restart: `flutter run -d edge`
- Check browser console for errors

---

## Quick Test Query

Run this to see all returns with their order info:

```sql
SELECT 
    r.id as return_id,
    r.order_id,
    r.return_status,
    r.refund_amount,
    r.created_at as return_date,
    o.customer_name,
    o.order_status,
    o.id as full_order_id,
    SUBSTRING(o.id::text, 1, 12) as short_order_id
FROM returns r
LEFT JOIN orders o ON o.id = r.order_id
ORDER BY r.created_at DESC
LIMIT 10;
```

This shows:
- All returns
- Which orders they're linked to
- The short order ID (to match with mobile app)

---

**Check the browser console first - it will tell you exactly what's happening!** 🔍

