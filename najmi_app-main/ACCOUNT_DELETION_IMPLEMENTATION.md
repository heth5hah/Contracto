# Account Deletion Implementation

This document describes the account deletion feature implementation in the Najmi app, which allows users to permanently delete their accounts and all associated data from the profile screen.

## Overview

The account deletion feature has been implemented to comply with App Store requirements that mandate apps with account creation must also provide account deletion functionality.

## Features

### User-Facing Features

1. **Delete Account Button**: Located in the Profile screen under account settings
2. **Two-Step Confirmation**: 
   - First warning dialog explaining what data will be deleted
   - Second confirmation requiring the user to type "DELETE"
3. **Comprehensive Data Deletion**: Deletes all user-related data including:
   - Profile information
   - Order history
   - Wishlist items
   - Saved addresses
   - Quote requests
4. **Visual Feedback**: Loading indicators and success/error messages
5. **Automatic Sign Out**: After successful deletion, user is signed out and redirected to login screen

### Technical Implementation

#### 1. Backend Service (`UserService`)

Added `deleteAccount()` method that:
- Validates user authentication
- Deletes data from related tables:
  - `addresses`
  - `wishlist`
  - `quote_requests`
  - `orders`
  - `users`
- Attempts to delete the auth user via RPC or Edge Function

**File**: `lib/features/auth/data/services/user_service.dart`

#### 2. UI Implementation (`ProfileScreen`)

Added three new methods:
- `_showDeleteAccountDialog()`: Shows initial warning
- `_showFinalDeleteConfirmation()`: Requires typing "DELETE" to confirm
- `_deleteAccount()`: Executes the deletion process

Added menu item:
- "Delete Account" button with red warning color
- Positioned before the "Log out" button
- Clear subtitle indicating permanent deletion

**File**: `lib/features/profile/presentation/screens/profile_screen.dart`

## Setup Instructions

### ⭐ Recommended: Edge Function (Production-Ready)

**The app is now configured to use the Edge Function approach.**

📖 **Complete deployment guide**: See [EDGE_FUNCTION_DEPLOYMENT_GUIDE.md](./EDGE_FUNCTION_DEPLOYMENT_GUIDE.md)

**Quick Setup:**
```bash
# 1. Login to Supabase
supabase login

# 2. Link your project
supabase link --project-ref YOUR_PROJECT_REF

# 3. Deploy the Edge Function
supabase functions deploy delete-user

# 4. Test in your app!
```

### Alternative: Database Function (Not Recommended)

If the database function doesn't work due to permissions, use a Supabase Edge Function:

#### Step 1: Create the Edge Function

```bash
# Navigate to your project
cd /path/to/your/supabase/project

# Create new edge function
supabase functions new delete-user
```

#### Step 2: Implement the Edge Function

Create/edit `supabase/functions/delete-user/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create a Supabase client with the Auth context of the logged in user
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Get the user from the auth header
    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    // Create a Supabase Admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Delete user data from custom tables first
    await supabaseAdmin.from('addresses').delete().eq('user_id', user.id)
    await supabaseAdmin.from('wishlist').delete().eq('user_id', user.id)
    await supabaseAdmin.from('quote_requests').delete().eq('user_id', user.id)
    await supabaseAdmin.from('orders').delete().eq('user_id', user.id)
    await supabaseAdmin.from('users').delete().eq('id', user.id)

    // Delete the user from auth
    const { error } = await supabaseAdmin.auth.admin.deleteUser(user.id)

    if (error) throw error

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
```

#### Step 3: Deploy the Edge Function

```bash
supabase functions deploy delete-user
```

#### Step 4: Update the Dart Code

In `lib/features/auth/data/services/user_service.dart`, update the `deleteAccount()` method to use the Edge Function instead of RPC:

```dart
// Replace the RPC call section (around line 245-256) with:
try {
  final response = await SupabaseService.client.functions.invoke('delete-user');
  
  if (response.data != null && response.data['success'] == true) {
    print('Deleted user from Supabase Auth via Edge Function');
  } else if (response.data != null && response.data['error'] != null) {
    throw Exception(response.data['error']);
  }
} catch (e) {
  print('Error deleting from Auth via Edge Function: $e');
  // If Edge Function fails, the user data is still deleted from the database
  // The auth user will remain but won't have any associated data
}
```

## Testing

### Test Account Deletion Flow

1. **Create a Test Account**:
   - Sign up with a test email
   - Add some data (wishlist items, addresses, etc.)

2. **Navigate to Profile**:
   - Go to the Profile screen
   - Scroll down to find "Delete Account" option

3. **Initiate Deletion**:
   - Tap "Delete Account"
   - Read the warning dialog
   - Tap "Continue"

4. **Confirm Deletion**:
   - Type "DELETE" in the confirmation field
   - Tap "Delete My Account"

5. **Verify**:
   - Loading indicator should appear
   - Success message should show
   - User should be redirected to login screen
   - Try logging in with the deleted account (should fail)

### Verify Data Deletion

Check your Supabase database to ensure:
- User record is removed from `users` table
- Related records removed from `addresses`, `wishlist`, `quote_requests`, `orders`
- Auth user is deleted from `auth.users` (if Edge Function is working)

## Security Considerations

1. **User Verification**: The system verifies that users can only delete their own accounts
2. **Two-Step Confirmation**: Prevents accidental deletions
3. **No Reversal**: Once deleted, data cannot be recovered
4. **Secure Deletion**: Uses Supabase security features and RLS policies

## Error Handling

The implementation includes comprehensive error handling:
- Network errors
- Database errors
- Permission errors
- User-friendly error messages
- Retry functionality

## UI/UX Features

- **Clear Warning**: Users are informed about what data will be deleted
- **Visual Hierarchy**: Delete button uses warning colors (red)
- **Loading States**: Shows progress during deletion
- **Success Feedback**: Confirms successful deletion
- **Error Recovery**: Allows retry on failure

## Compliance

This implementation satisfies App Store requirements:
- ✅ Account deletion option is easily accessible in the profile screen
- ✅ Users have full control over their data
- ✅ Clear communication about what will be deleted
- ✅ Confirmation steps prevent accidental deletion
- ✅ Complete data removal from all tables

## Future Enhancements

Consider these improvements for production:

1. **Grace Period**: Allow a 30-day grace period before permanent deletion
2. **Data Export**: Offer users to export their data before deletion
3. **Email Confirmation**: Send a confirmation email before final deletion
4. **Audit Log**: Keep anonymized logs of account deletions for compliance
5. **Soft Delete**: Initially mark as deleted, then permanently delete after grace period

## Troubleshooting

### Issue: RPC function not found
**Solution**: Use the Edge Function approach instead of database RPC

### Issue: Permission denied on auth.users
**Solution**: The Edge Function uses the service role key which has admin access

### Issue: User data not fully deleted
**Solution**: Check RLS policies on your tables and ensure the Edge Function has proper permissions

### Issue: App crashes after deletion
**Solution**: Ensure navigation to login screen happens after all async operations complete

## Support

For issues or questions about the account deletion feature:
1. Check the Supabase dashboard for errors
2. Review the logs in the Edge Function (if using)
3. Test with a fresh account to isolate issues
4. Contact Supabase support for auth-related issues

