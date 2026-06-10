const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qboyfdwwrimditugblwo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'
);

async function main() {
  await supabase.auth.signInWithPassword({
    email: 'hethshah05@gmail.com',
    password: '12345678'
  });

  const { data: order, error } = await supabase
    .from('orders')
    .select('*')
    .eq('id', 'd580a7aa-1711-4d97-b7b5-e299d71cfbe3')
    .single();

  if (error) {
    console.error('Error fetching order:', error);
    return;
  }

  console.log('Clearance Order Details:', order);

  const { data: items } = await supabase
    .from('orders')
    .select('items')
    .eq('id', order.id)
    .single();
  console.log('Clearance Order Items:', JSON.stringify(items, null, 2));

  // Let's check credit usage related to this order ID
  const { data: usage } = await supabase
    .from('credit_usage')
    .select('*')
    .eq('order_id', order.id);
  console.log('Credit Usage records for this order:', usage);
}

main().catch(console.error);
