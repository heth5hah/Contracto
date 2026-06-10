const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qboyfdwwrimditugblwo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'
);

async function main() {
  await supabase.auth.signInWithPassword({
    email: 'hethshah05@gmail.com',
    password: '12345678' // Using admin login just in case
  }).catch(() => {});

  console.log("=== Updating order aea20aa5 ===");
  const { data, error } = await supabase
    .from('orders')
    .update({ payment_status: 'paid' })
    .eq('id', 'aea20aa5-88f0-4408-8b14-0d2d12fbaec3')
    .select();

  if (error) {
    console.error("Error updating order:", error);
  } else {
    console.log("Update result:", data);
  }
}

main().catch(console.error);
