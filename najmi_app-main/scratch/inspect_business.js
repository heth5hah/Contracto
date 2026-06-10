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

  const { data: clearanceOrders } = await supabase
    .from('orders')
    .select('id, total_amount, payment_status, order_status, items')
    .eq('payment_source', 'credit_clearance');

  console.log('=== Clearance Orders ===');
  clearanceOrders.forEach(co => {
    console.log(`ID: ${co.id} | Amount: ${co.total_amount} | Payment: ${co.payment_status} | Status: ${co.order_status}`);
    console.log('Items:', JSON.stringify(co.items, null, 2));
    console.log('--------------------------------------------------');
  });
}

main().catch(console.error);
