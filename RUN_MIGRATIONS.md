# 🚀 Run Return Feature Migrations

## Quick Start

### Option 1: Run Combined Migration (Recommended)

1. **Open Supabase Dashboard**
   - Go to your Supabase project
   - Navigate to **SQL Editor**

2. **Copy and Paste**
   - Open the file: `admin+app/run_all_return_migrations.sql`
   - Copy the entire contents
   - Paste into Supabase SQL Editor

3. **Execute**
   - Click **Run** or press `Ctrl+Enter` (Windows) / `Cmd+Enter` (Mac)
   - Wait for "Success" message

4. **Verify** (Optional)
   - Scroll to the bottom of the SQL file
   - Run the verification queries one by one
   - All should return expected results

---

### Option 2: Run Individual Migrations

If you prefer to run them separately, execute in this order:

1. **First:** `admin+app/add_return_policy_settings.sql`
2. **Second:** `admin+app/najmi_app-main/add_returns_tables.sql`
3. **Third:** `admin+app/return_validation_function.sql`

---

## ✅ What Gets Created

### Tables
- ✅ `settings` - Stores return policy configuration
- ✅ `returns` - Stores return requests
- ✅ `return_items` - Stores items in each return

### Columns
- ✅ `orders.delivered_at` - Tracks when order was delivered

### Functions
- ✅ `validate_return_request()` - Validates return eligibility
- ✅ `validate_return_before_insert()` - Trigger function
- ✅ `update_returns_updated_at()` - Auto-updates timestamp
- ✅ `update_settings_updated_at()` - Auto-updates timestamp

### Triggers
- ✅ `validate_return_request_trigger` - Prevents invalid returns
- ✅ `returns_updated_at_trigger` - Auto-updates timestamp
- ✅ `settings_updated_at_trigger` - Auto-updates timestamp

### Policies (RLS)
- ✅ Settings: Public read, authenticated write
- ✅ Returns: Users can view/create/update their own
- ✅ Return Items: Users can view/create their own

---

## 🔍 Verification

After running the migration, verify with these queries:

```sql
-- 1. Check return policy settings exist
SELECT * FROM settings WHERE key = 'return_policy';
-- Should return: {"returns_enabled": true, "return_window_days": 7}

-- 2. Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('returns', 'return_items', 'settings');
-- Should return 3 rows

-- 3. Check delivered_at column
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'orders' AND column_name = 'delivered_at';
-- Should return 1 row

-- 4. Check functions exist
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%return%' OR routine_name LIKE '%settings%';
-- Should return multiple rows
```

---

## 🐛 Troubleshooting

### Error: "relation already exists"
- **Solution:** This is OK! The migration uses `IF NOT EXISTS` clauses, so it's safe to run multiple times.

### Error: "permission denied"
- **Solution:** Make sure you're logged in as a user with database admin privileges in Supabase.

### Error: "column already exists"
- **Solution:** The `delivered_at` column might already exist. This is fine - the migration handles it.

### Tables not showing in Supabase Dashboard
- **Solution:** Refresh the page or check the `public` schema filter.

---

## 📝 Next Steps

After successful migration:

1. ✅ **Test in Admin Panel**
   - Go to Settings → Return Policy
   - Verify you can change return window
   - Toggle returns on/off

2. ✅ **Test in Mobile App**
   - Mark an order as "Delivered"
   - Open Order Details
   - Verify "Return Items" button appears
   - Test return flow

3. ✅ **Update Existing Orders** (if needed)
   ```sql
   -- Set delivered_at for existing delivered orders
   UPDATE orders 
   SET delivered_at = COALESCE(updated_at, created_at, now())
   WHERE order_status = 'delivered' AND delivered_at IS NULL;
   ```

---

## 🎉 Success!

If all verification queries pass, your return feature is ready to use!

For detailed documentation, see: `PARTIAL_RETURN_IMPLEMENTATION.md`

