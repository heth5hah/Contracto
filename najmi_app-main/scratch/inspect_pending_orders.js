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

  console.log("=== Fetching Quote Requests ===");
  const { data: quotes, error: qErr } = await supabase
    .from('quote_requests')
    .select('id, created_at, payment_method, total_amount, status, transaction_id')
    .eq('user_id', userId)
    .eq('payment_method', 'credit');

  if (qErr) console.error(qErr);
  else console.log("Quotes:", quotes);

  console.log("\n=== Fetching Regular Orders ===");
  const { data: orders, error: oErr } = await supabase
    .from('orders')
    .select('id, created_at, total_amount, payment_source, payment_status, order_status, transaction_id')
    .eq('user_id', userId);

  if (oErr) console.error(oErr);
  else {
    console.log("All orders fetched:", orders.length);
    orders.forEach(o => {
      console.log(`Order: ${o.id} | Amt: ${o.total_amount} | Status: ${o.order_status} | PayStatus: ${o.payment_status} | Source: ${o.payment_source} | TxnId: ${o.transaction_id}`);
    });
  }
}

main().catch(console.error);
