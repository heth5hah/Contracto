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

  const { data: creditOrders } = await supabase
    .from('quote_requests')
    .select('id, created_at, payment_method, total_amount, quotes(total_amount), transaction_id, quote_request_items(products(product_name, name, image_url))')
    .eq('user_id', userId)
    .eq('payment_method', 'credit')
    .eq('status', 'quotation_accepted');

  const { data: regularOrders } = await supabase
    .from('orders')
    .select('id, created_at, total_amount, payment_source, payment_status, order_status, transaction_id, items')
    .eq('user_id', userId)
    .or('payment_source.eq.credit,payment_method.ilike.%credit%')
    .not('payment_status', 'eq', 'paid')
    .not('order_status', 'in', '("cancelled","returned","rejected")');

  const allPending = [];
  let total = 0;

  console.log("=== Evaluating Quotes ===");
  for (const q of (creditOrders || [])) {
    const amount = ((q.quotes && q.quotes.length > 0)
            ? (q.quotes[0].total_amount)
            : null) ||
        (q.total_amount) ||
        0.0;
    if (amount > 0) {
      const status = q.status;
      const payStatus = q.payment_status;
      if (status === 'order_placed' ||
          status === 'paid' ||
          payStatus === 'paid' ||
          payStatus === 'completed') {
        console.log(`Quote ${q.id}: skipped because status is ${status} or payStatus is ${payStatus}`);
        continue;
      }

      const txnId = q.transaction_id;
      const isCreditTxn = txnId != null && txnId.startsWith('CREDIT-');
      if (txnId != null && txnId !== '' && !isCreditTxn) {
        console.log(`Quote ${q.id}: skipped because txnId is ${txnId}`);
        continue;
      }

      console.log(`Quote ${q.id}: KEPT! Amt: ${amount}`);
      allPending.push({ type: 'quote', id: q.id, amount });
      total += amount;
    }
  }

  console.log("\n=== Evaluating Regular Orders ===");
  for (const o of (regularOrders || [])) {
    const amount = o.total_amount || 0.0;
    if (amount > 0) {
      const txnId = o.transaction_id;
      const payStatus = o.payment_status;
      const isCreditTxn = txnId == null || txnId === '' || txnId.startsWith('CREDIT-');
      if (payStatus === 'paid' ||
          payStatus === 'completed' ||
          (!isCreditTxn)) {
        console.log(`Order ${o.id}: skipped (payStatus: ${payStatus}, txnId: ${txnId}, isCreditTxn: ${isCreditTxn})`);
        continue;
      }

      console.log(`Order ${o.id}: KEPT! Amt: ${amount}`);
      allPending.push({ type: 'order', id: o.id, amount });
      total += amount;
    }
  }

  console.log("\nFinal list size:", allPending.length);
  console.log("Calculated total:", total);
}

main().catch(console.error);
