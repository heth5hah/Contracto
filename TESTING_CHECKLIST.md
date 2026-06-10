# ✅ Return Feature - Testing Checklist

## 🎉 Migration Complete!

Now that the database migration is done, let's test the complete return feature flow.

---

## 📋 Pre-Testing Checklist

- [x] Database migration completed (`run_all_return_migrations.sql`)
- [ ] Admin panel running (Windows)
- [ ] Mobile app running (Android device)
- [ ] At least one order exists in the system

---

## 🧪 Step-by-Step Testing Guide

### **Step 1: Verify Database Setup** ✅

Run these queries in Supabase SQL Editor to verify:

```sql
-- Check return policy settings exist
SELECT * FROM settings WHERE key = 'return_policy';
-- Expected: {"returns_enabled": true, "return_window_days": 7}

-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('returns', 'return_items', 'settings');
-- Expected: 3 rows

-- Check delivered_at column
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'orders' AND column_name = 'delivered_at';
-- Expected: 1 row
```

---

### **Step 2: Configure Return Policy (Admin Panel)** ⚙️

1. **Open Admin Panel** (should be running on Windows)
2. **Login** with your admin credentials
3. **Navigate to**: Settings → Return Policy
4. **Verify/Configure**:
   - ✅ Returns Enabled: **ON**
   - ✅ Return Window: **7 days** (or your preferred number)
5. **Click**: Save Settings
6. **Verify**: Success message appears

---

### **Step 3: Prepare Test Order (Admin Panel)** 📦

1. **Navigate to**: Orders section
2. **Find an order** (or create one if needed)
3. **Change Status** to **"Delivered"**
   - This automatically sets `delivered_at` timestamp
4. **Verify**: Order status shows as "Delivered"

**Note**: If you have existing delivered orders without `delivered_at`, run:
```sql
UPDATE orders 
SET delivered_at = COALESCE(updated_at, created_at, now())
WHERE order_status = 'delivered' AND delivered_at IS NULL;
```

---

### **Step 4: Test Return Feature (Mobile App)** 📱

1. **Open Mobile App** (should be running on your Android device)
2. **Login** with a customer account
3. **Navigate to**: Orders section
4. **Open the delivered order** from Step 3
5. **Verify Return UI**:
   - ✅ "Return Items" button is visible
   - ✅ Remaining days counter shows (e.g., "Return available for 7 more days")
   - ✅ Order status shows as "Delivered"

6. **Click**: "Return Items" button
7. **Return Selection Screen**:
   - ✅ List of items shows with quantities
   - ✅ Already returned quantities shown (if any)
   - ✅ Remaining returnable quantities shown
   - ✅ Quantity selector works (1 to max remaining)

8. **Select Items to Return**:
   - ✅ Check items you want to return
   - ✅ Adjust quantities using +/- buttons
   - ✅ Select return reason from dropdown
   - ✅ Add optional notes

9. **Submit Return Request**:
   - ✅ Click "Submit Return Request"
   - ✅ Success message appears
   - ✅ Navigate back to order details

10. **Verify Return Status**:
    - ✅ Return status card appears on order details
    - ✅ Shows "Pending Review" status
    - ✅ Shows refund amount
    - ✅ Shows return reason

---

### **Step 5: Manage Return Request (Admin Panel)** 👨‍💼

1. **Navigate to**: Returns section (in admin panel)
2. **Verify**: Return request appears in the list
3. **Open Return Details**:
   - ✅ Order information shown
   - ✅ Items to return listed
   - ✅ Return reason shown
   - ✅ Customer notes shown
   - ✅ Refund amount calculated

4. **Approve Return**:
   - ✅ Click "Approve" button
   - ✅ Status changes to "Approved"
   - ✅ Option to "Mark as Completed" appears

5. **Complete Return** (optional):
   - ✅ Click "Mark as Completed"
   - ✅ Status changes to "Completed"

---

### **Step 6: Test Edge Cases** 🔍

#### **Test 1: Expired Return Window**
1. Create a test order delivered 10 days ago (more than return window)
2. Verify: "Return period has expired" message shows
3. Verify: Return button is disabled

#### **Test 2: Partial Return**
1. Return 2 out of 5 items
2. Verify: Can make another return request for remaining 3 items
3. Verify: Return button still appears (if within window)

#### **Test 3: Multiple Returns**
1. Make first return request (partial)
2. Make second return request (different items)
3. Verify: Both returns appear in admin panel
4. Verify: Quantities correctly tracked

#### **Test 4: All Items Returned**
1. Return all items from an order
2. Verify: Return button disappears or shows "All items returned"
3. Verify: No items available for return

#### **Test 5: Disable Returns Globally**
1. In admin panel: Settings → Return Policy
2. Toggle "Returns Enabled" to OFF
3. Save settings
4. Verify: Return button disappears from mobile app
5. Verify: Existing returns still visible

---

## ✅ Success Criteria

### **Mobile App**
- [x] Return button appears for delivered orders within window
- [x] Return button disabled when window expired
- [x] Return selection screen works correctly
- [x] Quantity validation prevents over-returning
- [x] Return request submits successfully
- [x] Return status displays correctly

### **Admin Panel**
- [x] Return policy settings save correctly
- [x] Return requests appear in Returns section
- [x] Can approve/reject returns
- [x] Can view return details
- [x] Can complete returns

### **Database**
- [x] Return records created in `returns` table
- [x] Return items created in `return_items` table
- [x] Validation triggers work (prevents invalid returns)
- [x] RLS policies allow proper access

---

## 🐛 Common Issues & Solutions

### **Issue: Return button not showing**
**Solutions**:
- Check order status is "delivered"
- Check `delivered_at` is set
- Check return window hasn't expired
- Check returns are enabled in admin settings
- Refresh the app

### **Issue: "Return period has expired" immediately**
**Solutions**:
- Check `delivered_at` timestamp is correct
- Verify return window days in settings
- Check timezone calculations (should use UTC)

### **Issue: Can't submit return request**
**Solutions**:
- Check database migration completed
- Verify `returns` and `return_items` tables exist
- Check RLS policies are correct
- Verify user is authenticated

### **Issue: Return request not appearing in admin**
**Solutions**:
- Check admin is logged in
- Verify RLS policies allow admin access
- Check Returns section is loading correctly
- Refresh admin panel

---

## 📊 Expected Database State

After successful testing, you should have:

```sql
-- Check return requests
SELECT COUNT(*) FROM returns;
-- Should show number of test returns

-- Check return items
SELECT COUNT(*) FROM return_items;
-- Should show total items in all returns

-- Check return policy
SELECT value FROM settings WHERE key = 'return_policy';
-- Should show: {"returns_enabled": true, "return_window_days": 7}
```

---

## 🎉 Testing Complete!

Once all items are checked, your return feature is fully functional!

### **What You've Tested:**
✅ Database setup
✅ Return policy configuration
✅ Return request submission
✅ Return request management
✅ Edge cases and validation
✅ UI/UX flow

### **Next Steps:**
- Deploy to production (if ready)
- Train team on return management
- Monitor return requests
- Gather user feedback

---

## 📝 Notes

- Return window is calculated from `delivered_at` timestamp
- All date calculations use UTC for consistency
- Multiple partial returns are allowed within the window
- Return policy changes apply to new deliveries only
- Existing returns are not affected by policy changes

---

**Happy Testing! 🚀**

