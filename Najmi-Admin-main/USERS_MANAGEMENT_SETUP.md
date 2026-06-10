# Users Management Setup Guide

## Problem
If you're seeing "No users found" in the admin panel, it's likely due to Row Level Security (RLS) policies blocking admin access to the users table.

## Solution

### Step 1: Run the RLS Policy SQL File

1. Open your Supabase Dashboard
2. Go to SQL Editor
3. Run the file: `admin_users_rls_policies.sql`

This will:
- Drop existing conflicting policies
- Create new policies that allow:
  - Users to view/update their own data
  - Admins to view/update/delete ALL users
  - Users to insert their own records during registration

### Step 2: Verify and Set Your Admin User

**This is the most common issue!** Your user must have `role = 'admin'` in the `users` table.

**Option A: Use the diagnostic script (Recommended)**
1. Run `check_and_fix_admin_user.sql` in Supabase SQL Editor
2. It will automatically set your current user as admin
3. It also shows diagnostic information

**Option B: Manual SQL**
```sql
-- Check your current user's role
SELECT id, email, name, role FROM users WHERE id = auth.uid();

-- If your role is not 'admin', update it:
UPDATE users 
SET role = 'admin' 
WHERE id = auth.uid();

-- Verify the update
SELECT id, email, name, role FROM users WHERE id = auth.uid();
```

**Option C: Update by email (if you know your email)**
```sql
UPDATE users 
SET role = 'admin' 
WHERE email = 'your-email@example.com';
```

### Step 3: Verify Policies Are Created

Run this query to see all policies on the users table:

```sql
SELECT 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY policyname;
```

You should see:
- "Users can insert their own record" (INSERT)
- "Users can read their own record" (SELECT)
- "Users can update their own record" (UPDATE)
- "Admins can read all users" (SELECT)
- "Admins can update any user" (UPDATE)
- "Admins can delete any user" (DELETE)

### Step 4: Test the Admin Panel

1. Log out and log back in as admin
2. Navigate to the Users section
3. You should now see all users in the database

## Troubleshooting

### Still seeing "No users found"?

**Most Common Causes:**

1. **Your user is not set as admin** (90% of cases)
   - Run `check_and_fix_admin_user.sql` in Supabase
   - Or manually run: `UPDATE users SET role = 'admin' WHERE id = auth.uid();`
   - **After updating, log out and log back in**

2. **Check console logs**: 
   - Open browser DevTools (F12) → Console tab
   - Look for error messages or warnings
   - The app now shows detailed error messages

3. **Verify authentication**: 
   - Make sure you're logged in to the admin panel
   - Check if `auth.uid()` returns your user ID

4. **Check user role**: 
   ```sql
   SELECT id, email, role FROM users WHERE id = auth.uid();
   ```
   - Should show `role = 'admin'`

5. **Check RLS policies**: 
   ```sql
   SELECT policyname, cmd FROM pg_policies WHERE tablename = 'users';
   ```
   - Should show "Admins can read all users" policy

6. **Test the function**:
   ```sql
   SELECT public.is_admin(auth.uid());
   ```
   - Should return `true` if you're admin

7. **Try refreshing**: 
   - Log out completely
   - Log back in
   - Refresh the page

### Error: "RLS policy violation"

This means the RLS policies are blocking access. Make sure:
- You've run the `admin_users_rls_policies.sql` file
- Your user has `role = 'admin'` in the users table
- You're logged in with the correct account

### Error: "Not authenticated"

Make sure you're logged in to the admin panel before accessing the users section.

## Notes

- The RLS policies use a subquery to check if the current user is an admin
- This avoids circular dependency issues
- Regular users can still only see their own data
- Only users with `role = 'admin'` can see all users

