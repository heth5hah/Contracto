# Users Section Troubleshooting Guide

## Problem: "No users found" even though users exist in database

This is almost always an RLS (Row Level Security) policy issue.

## Step-by-Step Diagnosis

### Step 1: Verify Users Exist in Database

Run this in Supabase SQL Editor:
```sql
-- This bypasses RLS to show actual count
SELECT COUNT(*) as total_users FROM public.users;
```

**If this returns 0:** There are no users in the database.  
**If this returns > 0:** Users exist, but RLS is blocking access.

### Step 2: Check Your Admin Status

```sql
-- Check your current user
SELECT 
    id,
    email,
    name,
    role,
    status
FROM public.users
WHERE id = auth.uid();
```

**Expected:** `role = 'admin'`  
**If not:** Run `force_admin_role.sql`

### Step 3: Test the is_admin Function

```sql
-- This should return true
SELECT public.is_admin(auth.uid());
```

**If false:** Your role is not set correctly.  
**If true:** The function works, but RLS policies might have an issue.

### Step 4: Test RLS Policies

```sql
-- Try to select all users (this will be blocked by RLS if not admin)
SELECT id, email, role FROM public.users LIMIT 5;
```

**If empty:** RLS is blocking (even though you're admin)  
**If returns data:** RLS works, but the app query might have an issue

### Step 5: Temporarily Disable RLS (TESTING ONLY)

⚠️ **WARNING: This removes security! Only for testing!**

```sql
-- Disable RLS temporarily
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Now try the query again in the app
-- If users appear, RLS policies are the issue

-- Re-enable RLS after testing
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
```

### Step 6: Recreate RLS Policies

If disabling RLS made users appear, the policies need to be fixed:

1. Run `admin_users_rls_policies.sql` again
2. Make sure the `is_admin()` function exists and works
3. Verify your role is 'admin'
4. Log out and log back in

## Common Issues and Solutions

### Issue 1: Role is NULL or empty
**Solution:**
```sql
UPDATE public.users 
SET role = 'admin' 
WHERE id = auth.uid();
```

### Issue 2: Role is 'Admin' (capital A) instead of 'admin'
**Solution:** The function now handles this, but ensure it's lowercase:
```sql
UPDATE public.users 
SET role = LOWER(role) 
WHERE id = auth.uid();
```

### Issue 3: is_admin() function doesn't exist
**Solution:** Run `admin_users_rls_policies.sql` to create it

### Issue 4: Function exists but returns false
**Solution:** 
1. Check if your user record exists:
   ```sql
   SELECT * FROM public.users WHERE id = auth.uid();
   ```
2. If missing, you need to create a user record first
3. Then set role to admin

### Issue 5: Policies exist but still blocking
**Solution:**
1. Drop all policies:
   ```sql
   DROP POLICY IF EXISTS "Admins can read all users" ON public.users;
   DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
   -- etc.
   ```
2. Recreate using `admin_users_rls_policies.sql`

## Quick Fix Script

Run this complete fix script:

```sql
-- 1. Set your role as admin
UPDATE public.users 
SET role = 'admin' 
WHERE id = auth.uid();

-- 2. Verify
SELECT id, email, role FROM public.users WHERE id = auth.uid();

-- 3. Test function
SELECT public.is_admin(auth.uid());

-- 4. Test query
SELECT COUNT(*) FROM public.users;
```

## Still Not Working?

1. **Check browser console (F12)** - Look for detailed error messages
2. **Check Supabase logs** - Dashboard → Logs → API Logs
3. **Verify authentication** - Make sure you're logged in
4. **Try a different browser** - Clear cache and cookies
5. **Check network tab** - See the actual API request/response

## Contact Support

If none of these work, provide:
- Browser console logs
- Results of the diagnostic queries above
- Supabase API logs
- Your user ID and email

