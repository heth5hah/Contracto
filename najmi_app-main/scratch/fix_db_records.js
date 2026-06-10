const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qboyfdwwrimditugblwo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'
);

async function main() {
  // Login as admin
  console.log('Logging in as admin...');
  const loginResult = await supabase.auth.signInWithPassword({
    email: 'hethshah05@gmail.com',
    password: '12345678'
  });

  if (loginResult.error) {
    console.error('Login failed:', loginResult.error);
    return;
  }
  console.log('Logged in successfully!');

  const accountId = '65e10686-3736-4c97-b73d-fc56adf36fcb';
  const orderId = 'd580a7aa-1711-4d97-b7b5-e299d71cfbe3';

  // 1. Fetch current credit account details
  const { data: creditAccount, error: fetchErr } = await supabase
    .from('business_credit_accounts')
    .select('*')
    .eq('id', accountId)
    .single();

  if (fetchErr) {
    console.error('Error fetching credit account:', fetchErr);
    return;
  }
  console.log('Current credit account details:', creditAccount);

  // 2. Perform the update to restore credit
  console.log('Updating business_credit_accounts...');
  const { data: updatedAccount, error: updateErr } = await supabase
    .from('business_credit_accounts')
    .update({
      available_credit: 600000.0,
      used_credit: 0.0,
      updated_at: new Date().toISOString()
    })
    .eq('id', accountId)
    .select();

  if (updateErr) {
    console.error('Error updating credit account:', updateErr);
  } else {
    console.log('Updated credit account details:', updatedAccount);
  }

  // 3. Insert the credit transaction into credit_usage
  console.log('Inserting credit transaction into credit_usage...');
  const { data: insertedUsage, error: insertErr } = await supabase
    .from('credit_usage')
    .insert({
      credit_account_id: accountId,
      order_id: orderId,
      transaction_type: 'credit',
      amount: 5900.0,
      description: 'Payment confirmed by admin for Order #D580A7AA',
      balance_after: 600000.0
    })
    .select();

  if (insertErr) {
    console.error('Error inserting credit_usage:', insertErr);
  } else {
    console.log('Inserted credit_usage details:', insertedUsage);
  }

  // 4. Run recount RPC
  console.log('Running recount RPC...');
  const { data: recountResult, error: recountErr } = await supabase
    .rpc('recount_business_credit_balances', { p_account_id: accountId });

  if (recountErr) {
    console.error('Error running recount RPC:', recountErr);
  } else {
    console.log('Recount RPC result:', recountResult);
  }
}

main().catch(console.error);
