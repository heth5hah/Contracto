-- Function to delete user from auth.users
-- This function allows authenticated users to delete their own account
-- Run this in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION delete_user(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if the user is deleting their own account
  IF auth.uid() != user_id THEN
    RAISE EXCEPTION 'You can only delete your own account';
  END IF;

  -- Delete the user from auth.users
  DELETE FROM auth.users WHERE id = user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user(uuid) TO authenticated;

-- Alternative approach: If the above doesn't work due to permissions,
-- you can use the Supabase Management API or create an Edge Function
-- Here's a comment with instructions for the Edge Function approach:

/*
ALTERNATIVE APPROACH - Supabase Edge Function:

1. Create a new Edge Function in your Supabase project:
   supabase functions new delete-user

2. Use this code in the Edge Function:

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

3. Deploy the Edge Function:
   supabase functions deploy delete-user

4. Update the user_service.dart to call this Edge Function instead of RPC:

   // In deleteAccount() method, replace the RPC call with:
   final response = await SupabaseService.client.functions.invoke('delete-user');
   if (response.error != null) {
     print('Error deleting from Auth via Edge Function: ${response.error}');
   }
*/


