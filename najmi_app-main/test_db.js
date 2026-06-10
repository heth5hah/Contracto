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

  const accountId = 'ece14a21-f0e7-497e-aea8-416b4f4a623b';

  // Update wallet to include both refunds: 200 + 50 = 250
  const { data: updAcc, error: updErr } = await supabase
    .from('business_credit_accounts')
    .update({
      available_credit: 250,
      used_credit: 0,
    })
    .eq('id', accountId)
    .select();
  
  console.log('Updated wallet:', JSON.stringify(updAcc, null, 2));
  if (updErr) console.log('Error:', updErr);

  // Try inserting credit_usage with order_id
  const entries = [
    {
      credit_account_id: accountId,
      transaction_type: 'credit',
      amount: 200,
      order_id: '9ceebe2b-f301-43dd-9a7c-e2b4375ee0e8',
      description: 'Return refund - Order #9CEEBE2B',
      balance_after: 200
    },
    {
      credit_account_id: accountId,
      transaction_type: 'credit',
      amount: 50,
      order_id: 'a0e4ae17-8c73-4705-ad52-90c094522f69',
      description: 'Return refund - Order #A0E4AE17',
      balance_after: 250
    }
  ];

  for (const entry of entries) {
    const { data, error } = await supabase
      .from('credit_usage')
      .insert(entry)
      .select();
    
    if (error) {
      console.log(`Credit usage error for ${entry.description}:`, error);
    } else {
      console.log(`✅ Credit usage created: ${entry.description}`);
    }
  }

  // Verify final state
  const { data: finalAcc } = await supabase
    .from('business_credit_accounts')
    .select('*')
    .eq('id', accountId);
  console.log('\nFinal wallet:', JSON.stringify(finalAcc, null, 2));

  const { data: finalUsage } = await supabase
    .from('credit_usage')
    .select('*')
    .eq('credit_account_id', accountId);
  console.log('Final usage:', JSON.stringify(finalUsage, null, 2));
}

main().catch(console.error);
