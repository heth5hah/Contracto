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

  const accountId = '65e10686-3736-4c97-b73d-fc56adf36fcb';

  console.log("=== Fetching Billing Cycles ===");
  const { data: cycles, error: cErr } = await supabase
    .from('billing_cycles')
    .select('*')
    .eq('credit_account_id', accountId);

  if (cErr) console.error(cErr);
  else console.log("Cycles:", cycles);
}

main().catch(console.error);
