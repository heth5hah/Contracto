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

  const userId = 'f5b790bd-97f3-4fec-b700-0a85339d34fd';

  console.log("=== Testing Exact Query ===");
  const { data: regularOrders, error: oErr } = await supabase
    .from('orders')
    .select('id, created_at, total_amount, payment_source, payment_status, order_status, transaction_id, items')
    .eq('user_id', userId)
    .or('payment_source.eq.credit,payment_method.ilike.%credit%')
    .not('payment_status', 'eq', 'paid')
    .not('order_status', 'in', '("cancelled","returned","rejected")');

  if (oErr) {
    console.error("Query Error:", oErr);
  } else {
    console.log("Returned orders:", regularOrders.length);
    regularOrders.forEach(o => {
      console.log(`Order: ${o.id} | Amt: ${o.total_amount} | Status: ${o.order_status} | PayStatus: ${o.payment_status} | Source: ${o.payment_source} | TxnId: ${o.transaction_id}`);
    });
  }
}

main().catch(console.error);
