# Account Deletion Fix - Deployment Instructions

## Problem
The account deletion was only removing data from custom tables but NOT deleting the user from Supabase Auth (`auth.users` table). This allowed users to still log in with deleted accounts.

## Solution
Created a Supabase Edge Function (`delete-user`) that:
1. Deletes all user data from custom tables (wishlist, addresses, orders, etc.)
2. **Deletes the user from `auth.users`** using the admin API

## Deployment Steps

### Step 1: Deploy the Edge Function

Run these commands in the project root directory:

```powershell
cd c:\Paid Project\admin_app_final\admin+app\najmi_app-main

# Login to Supabase (if not already logged in)
npx supabase login

# Link to your Supabase project (if not already linked)
npx supabase link --project-ref YOUR_PROJECT_REF

# Deploy the delete-user Edge Function
npx supabase functions deploy delete-user
```

Replace `YOUR_PROJECT_REF` with your actual Supabase project reference ID (found in your Supabase dashboard URL).

### Step 2: Verify the Edge Function is deployed

1. Go to your Supabase Dashboard
2. Navigate to **Edge Functions** in the sidebar
3. Verify that `delete-user` function is listed and active

### Step 3: Test the Account Deletion

1. Create a test account in the app
2. Try to delete the account
3. After deletion, try to log in with the same credentials
4. The login should FAIL because the account has been fully deleted

## Files Modified

1. **NEW**: `supabase/functions/delete-user/index.ts` - Edge Function to delete user from auth
2. **MODIFIED**: `lib/features/auth/data/services/user_service.dart` - Updated to call the Edge Function

## Fallback Behavior

If the Edge Function is not deployed or fails:
- The app will fall back to manual deletion from custom tables
- User will see a message that they need to contact support for complete account removal
- Their data will be deleted, but they can still log in (will need to re-register)

## Important Notes

- The Edge Function requires the `SUPABASE_SERVICE_ROLE_KEY` environment variable (automatically available in Edge Functions)
- Only the authenticated user can delete their own account (security check in place)
- All user data is deleted before the auth deletion to maintain referential integrity
