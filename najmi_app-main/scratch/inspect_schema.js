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

  // Let's check table columns by trying to insert a dummy row or querying postgrest schema
  const { data: creditUsageColumns, error: err1 } = await supabase
    .from('credit_usage')
    .select('*')
    .limit(1);
  console.log('credit_usage columns:', creditUsageColumns ? Object.keys(creditUsageColumns[0] || {}) : err1);

  const { data: creditPaymentsColumns, error: err2 } = await supabase
    .from('credit_payments')
    .select('*')
    .limit(1);
  console.log('credit_payments columns:', creditPaymentsColumns ? Object.keys(creditPaymentsColumns[0] || {}) : err2);

  const { data: billingCyclesColumns, error: err3 } = await supabase
    .from('billing_cycles')
    .select('*')
    .limit(1);
  console.log('billing_cycles columns:', billingCyclesColumns ? Object.keys(billingCyclesColumns[0] || {}) : err3);
}

main().catch(console.error);
