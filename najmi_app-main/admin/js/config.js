const SUPABASE_URL = 'https://qboyfdwwrimditugblwo.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDA0NjA0NywiZXhwIjoyMDY1NjIyMDQ3fQ.lhtOM4oew21nNQ8d37zjQ9M7gp1jj1zIFoB2FS0nFng';

// Initialize Supabase client
let supabaseClient = null;

async function initSupabase() {
    try {
        if (!supabaseClient && window.supabase) {
            console.log('Initializing Supabase client...');
            supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
                auth: {
                    autoRefreshToken: true,
                    persistSession: true,
                    detectSessionInUrl: true
                }
            });
            window.supabaseClient = supabaseClient;
            console.log('Supabase client initialized successfully');
        }
        return supabaseClient;
    } catch (error) {
        console.error('Error initializing Supabase:', error);
        return null;
    }
}

// Initialize immediately when script loads
initSupabase();

// Also initialize when DOM is loaded (as backup)
document.addEventListener('DOMContentLoaded', async () => {
    if (!window.supabaseClient) {
        await initSupabase();
    }
}); 