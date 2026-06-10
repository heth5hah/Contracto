const { createClient } = require('@supabase/supabase-js');

// Configuration
const SUPABASE_URL = 'https://qboyfdwwrimditugblwo.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDA0NjA0NywiZXhwIjoyMDY1NjIyMDQ3fQ.lhtOM4oew21nNQ8d37zjQ9M7gp1jj1zIFoB2FS0nFng';

// Get arguments
const args = process.argv.slice(2);
const email = args[0];
const newPassword = args[1];

if (!email || !newPassword) {
    console.log('\nUsage: node change_password.js <email> <new_password>');
    console.log('Example: node change_password.js test@example.com myNewSecurePassword123\n');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

async function changePassword() {
    console.log(`Searching for user: ${email}...`);
    try {
        // List users to find the correct ID
        const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
        if (listError) throw listError;

        const user = users.find(u => u.email.toLowerCase() === email.toLowerCase());

        if (!user) {
            console.error(`Error: User with email "${email}" not found.`);
            process.exit(1);
        }

        console.log(`User found (ID: ${user.id}). Updating password...`);

        // Update user password
        const { data, error: updateError } = await supabase.auth.admin.updateUserById(
            user.id,
            { password: newPassword }
        );

        if (updateError) throw updateError;

        console.log(`Success! Password for ${email} has been updated successfully.`);
    } catch (error) {
        console.error('An error occurred:', error.message || error);
        process.exit(1);
    }
}

changePassword();
