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

  console.log('User:', user);

  const { data: account } = await supabase
    .from('business_credit_accounts')
    .select('*')
    .eq('user_id', user.id)
    .single();

  console.log('Credit Account:', account);

  const { data: usage } = await supabase
    .from('credit_usage')
    .select('*')
    .eq('credit_account_id', account.id)
    .order('created_at', { ascending: false });

  console.log('=== Credit Usage Ledger ===');
  usage.forEach(u => {
    console.log(`[${u.created_at}] Type: ${u.transaction_type} | Amount: ${u.amount} | Balance After: ${u.balance_after} | Desc: ${u.description}`);
  });

  const { data: cycles } = await supabase
    .from('billing_cycles')
    .select('*')
    .eq('credit_account_id', account.id)
    .order('created_at', { ascending: false });

  console.log('=== Billing Cycles ===');
  cycles.forEach(c => {
    console.log(`ID: ${c.id} | Range: ${c.cycle_start_date} to ${c.cycle_end_date} | Outstanding: ${c.outstanding_amount} | Payments: ${c.total_payments} | Status: ${c.status}`);
  });
}

main().catch(console.error);
