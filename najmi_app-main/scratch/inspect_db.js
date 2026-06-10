const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qboyfdwwrimditugblwo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'
);

async function main() {
  // Sign in as hethshah05@gmail.com
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'hethshah05@gmail.com',
    password: '12345678'
  });

  if (authErr) {
    console.error('Authentication error:', authErr);
    return;
  }
  console.log('Signed in successfully as:', authData.user.email);

  // 1. Get user details
  const { data: userRows } = await supabase
    .from('users')
    .select('*')
    .eq('id', authData.user.id);
  console.log('User Row:', JSON.stringify(userRows, null, 2));

  // 2. Get credit account
  const { data: accounts } = await supabase
    .from('business_credit_accounts')
    .select('*')
    .eq('user_id', authData.user.id);
  console.log('Credit Account:', JSON.stringify(accounts, null, 2));

  // 3. Get all orders for this user
  const { data: orders, error: ordersErr } = await supabase
    .from('orders')
    .select('*')
    .eq('user_id', authData.user.id);

  if (ordersErr) {
    console.error('Error fetching orders:', ordersErr);
  } else {
    console.log(`=== Orders for ${authData.user.email} (${orders.length}) ===`);
    orders.forEach(o => {
      console.log(`Order ID: ${o.id}
Amount: ${o.total_amount} | Payment: ${o.payment_status} | Order: ${o.order_status} | Source: ${o.payment_source}
Txn ID: ${o.transaction_id}
Created At: ${o.created_at}
--------------------------------------`);
    });
  }

  // 4. Get quote requests for this user
  const { data: quotes, error: quotesErr } = await supabase
    .from('quote_requests')
    .select('*')
    .eq('user_id', authData.user.id);

  if (quotesErr) {
    console.error('Error fetching quotes:', quotesErr);
  } else {
    console.log(`=== Quotes for ${authData.user.email} (${quotes.length}) ===`);
    quotes.forEach(q => {
      console.log(`Quote ID: ${q.id}
Amount: ${q.total_amount} | Status: ${q.status} | Method: ${q.payment_method} | Txn ID: ${q.transaction_id}
Created At: ${q.created_at}
--------------------------------------`);
    });
  }
}

main().catch(console.error);
