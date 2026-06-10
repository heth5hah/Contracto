# Business Credit Widget Not Showing - Fix Guide

## Issue
Business Credit widget is not visible for business accounts.

## Root Causes
1. **Credit accounts not created for existing business users** - The trigger only creates accounts for NEW users
2. **KYC status is 'pending'** - Widget was hiding if KYC not approved

## ✅ Fix Applied

### 1. Widget Updated
- Widget now shows even if KYC is pending (with warning message)
- Shows KYC pending message in the widget
- Disables "Pay Due" button if KYC not approved

### 2. SQL Script Created
**File:** `admin/create_credit_accounts_for_existing_business_users.sql`

This script creates credit accounts for all existing business users.

## 🔧 Steps to Fix

### Step 1: Create Credit Accounts for Existing Users
Run this SQL in Supabase SQL Editor:

```sql
-- File: admin/create_credit_accounts_for_existing_business_users.sql
```

This will:
- Create credit accounts for all existing company users
- Set credit limit to ₹5,00,000
- Set KYC status to 'pending' (update manually after verification)

### Step 2: Approve KYC (Optional - for testing)
To enable full credit features, update KYC status:

```sql
-- Approve KYC for specific user
UPDATE business_credit_accounts 
SET kyc_status = 'approved', 
    kyc_approved_at = NOW()
WHERE user_id = 'YOUR_USER_ID_HERE';

-- Or approve all business users (for testing)
UPDATE business_credit_accounts 
SET kyc_status = 'approved', 
    kyc_approved_at = NOW()
WHERE kyc_status = 'pending';
```

### Step 3: Verify
1. Restart the app
2. Login as business account
3. Widget should appear on home screen
4. If KYC pending, you'll see warning message
5. If KYC approved, full features available

## Expected Behavior

### With KYC Pending:
- ✅ Widget visible
- ⚠️ Shows "KYC verification pending" message
- ❌ "Pay Due" button disabled
- ❌ Cannot use credit in checkout

### With KYC Approved:
- ✅ Widget visible
- ✅ Shows credit information
- ✅ "Pay Due" button enabled
- ✅ Can use credit in checkout

## Debug Checklist

If widget still not showing:

1. **Check user type:**
   ```sql
   SELECT id, email, user_type 
   FROM users 
   WHERE email = 'your-email@example.com';
   ```
   Should be `user_type = 'company'`

2. **Check credit account exists:**
   ```sql
   SELECT * 
   FROM business_credit_accounts 
   WHERE user_id = 'YOUR_USER_ID';
   ```
   Should return a row

3. **Check app logs:**
   - Look for "Error loading credit data" in console
   - Check if `_isBusinessAccount` is true in home screen

4. **Verify home screen condition:**
   - `_isLoggedIn` must be true
   - `_isBusinessAccount` must be true
   - `!_showSearchResults` must be true
   - `!_showCategoryResults` must be true

## Files Modified
- `lib/features/credit/presentation/widgets/business_credit_widget.dart` - Updated to show even with pending KYC
- `admin/create_credit_accounts_for_existing_business_users.sql` - New script to create accounts

