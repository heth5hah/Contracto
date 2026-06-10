const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qboyfdwwrimditugblwo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'
);

async function testLogin(email, password) {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      console.log(`Failed to log in as ${email}:`, error.message);
      return false;
    }
    console.log(`Successfully logged in as ${email}! User ID: ${data.user.id}`);
    return true;
  } catch (e) {
    console.log(`Exception logging in as ${email}:`, e);
    return false;
  }
}

async function main() {
  await testLogin('hethshah05@gmail.com', '12345678');
  await testLogin('hethshah05@gmail.com', '123456');
}

main().catch(console.error);
