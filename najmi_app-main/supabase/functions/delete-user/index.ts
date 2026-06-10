import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
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

        console.log(`Deleting user with ID: ${user.id}`)

        // Create a Supabase Admin client with service role key
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Delete user data from custom tables first (in order to respect foreign key constraints)

        // 1. Delete wishlist items
        try {
            await supabaseAdmin.from('wishlist').delete().eq('user_id', user.id)
            console.log('Deleted wishlist items')
        } catch (e) {
            console.log('Wishlist table may not exist or is empty:', e)
        }

        // 2. Delete addresses
        try {
            await supabaseAdmin.from('addresses').delete().eq('user_id', user.id)
            console.log('Deleted addresses')
        } catch (e) {
            console.log('Addresses table may not exist:', e)
        }

        // 3. Delete quote request items first, then quote requests
        try {
            const { data: quoteRequests } = await supabaseAdmin
                .from('quote_requests')
                .select('id')
                .eq('user_id', user.id)

            if (quoteRequests && quoteRequests.length > 0) {
                for (const qr of quoteRequests) {
                    await supabaseAdmin.from('quote_request_items').delete().eq('quote_request_id', qr.id)
                }
                await supabaseAdmin.from('quote_requests').delete().eq('user_id', user.id)
            }
            console.log('Deleted quote requests')
        } catch (e) {
            console.log('Quote requests table may not exist:', e)
        }

        // 4. Delete credit related data
        try {
            const { data: creditAccount } = await supabaseAdmin
                .from('business_credit_accounts')
                .select('id')
                .eq('user_id', user.id)
                .maybeSingle()

            if (creditAccount) {
                await supabaseAdmin.from('credit_usage').delete().eq('credit_account_id', creditAccount.id)
                await supabaseAdmin.from('credit_payments').delete().eq('credit_account_id', creditAccount.id)
                await supabaseAdmin.from('billing_cycles').delete().eq('credit_account_id', creditAccount.id)
                await supabaseAdmin.from('business_credit_accounts').delete().eq('user_id', user.id)
            }
            console.log('Deleted credit data')
        } catch (e) {
            console.log('Credit tables may not exist:', e)
        }

        // 5. Delete order items first, then orders
        try {
            const { data: orders } = await supabaseAdmin
                .from('orders')
                .select('id')
                .eq('user_id', user.id)

            if (orders && orders.length > 0) {
                for (const order of orders) {
                    await supabaseAdmin.from('order_items').delete().eq('order_id', order.id)
                }
                await supabaseAdmin.from('orders').delete().eq('user_id', user.id)
            }
            console.log('Deleted orders')
        } catch (e) {
            console.log('Orders table may not exist:', e)
        }

        // 6. Delete return requests
        try {
            await supabaseAdmin.from('return_requests').delete().eq('user_id', user.id)
            console.log('Deleted return requests')
        } catch (e) {
            console.log('Return requests table may not exist:', e)
        }

        // 7. Delete the user record from users table
        try {
            await supabaseAdmin.from('users').delete().eq('id', user.id)
            console.log('Deleted user record from users table')
        } catch (e) {
            console.log('Error deleting from users table:', e)
        }

        // 8. CRITICAL: Delete the user from Supabase Auth
        const { error } = await supabaseAdmin.auth.admin.deleteUser(user.id)

        if (error) {
            console.error('Error deleting user from auth:', error)
            throw error
        }

        console.log(`Successfully deleted user ${user.id} from auth`)

        return new Response(JSON.stringify({ success: true, message: 'Account deleted successfully' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })
    } catch (error) {
        console.error('Error in delete-user function:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
