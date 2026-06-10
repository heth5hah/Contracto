const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qboyfdwwrimditugblwo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'
);

async function main() {
  await supabase.auth.signInWithPassword({
    email: 'shaheth05@gmail.com',
    password: '12345678'
  });

  const { data: user } = await supabase
    .from('users')
    .select('id, name, email')
    .eq('email', 'shaheth05@gmail.com')
    .single();

  console.log('Logged in user:', user.email, 'ID:', user.id);

  const { data: orders, error } = await supabase
    .from('orders')
    .select('*')
    .eq('user_id', user.id);

  if (error) {
    console.error('Error fetching orders:', error);
  } else {
    console.log('Orders found:', orders.length);
    orders.forEach(o => {
      console.log(`Order ID: ${o.id} | Amount: ${o.total_amount} | Payment Status: ${o.payment_status} | Order Status: ${o.order_status} | Source: ${o.payment_source} | Txn ID: ${o.transaction_id}`);
    });
  }
}

main().catch(console.error);
