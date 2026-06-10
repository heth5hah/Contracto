console.log('Auth.js loaded');

// Wait for Supabase to be initialized
async function waitForSupabase() {
    return new Promise((resolve) => {
        const checkSupabase = () => {
            if (window.supabaseClient) {
                resolve(window.supabaseClient);
            } else {
                setTimeout(checkSupabase, 100);
            }
        };
        checkSupabase();
    });
}

// Function to get user's name from email
function getUserNameFromEmail(email) {
    if (!email) return '';
    const name = email.split('@')[0];
    // Capitalize first letter of each word and replace dots with spaces
    return name.split('.').map(word => 
        word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
    ).join(' ');
}

// Update user name in header
function updateUserName(email) {
    console.log('Updating user name with email:', email);
    const userNameElement = document.getElementById('userName');
    if (userNameElement) {
        const name = getUserNameFromEmail(email);
        console.log('Extracted name:', name);
        userNameElement.textContent = name;
    } else {
        console.warn('userName element not found in the DOM');
    }
}

// Helper: detect if we are currently on the login page
function isLoginPage() {
    const path = window.location.pathname;
    // Matches '/', '/index.html', or any path ending with /index.html
    return path === '/' || path.endsWith('/index.html') || path === '';
}

// Helper: get the root-relative path to the login page
function getLoginUrl() {
    // Always use absolute root-relative path
    return '/index.html';
}

// Helper: get the root-relative path to the dashboard
function getDashboardUrl() {
    return '/pages/dashboard.html';
}

// Check if user is authenticated
async function checkAuth() {
    try {
        console.log('Checking authentication...');
        const supabaseClient = await waitForSupabase();
        const { data: { session }, error: sessionError } = await supabaseClient.auth.getSession();
        
        if (sessionError) throw sessionError;
        
        if (!session) {
            console.log('No active session found');
            // If not on login page, redirect to login
            if (!isLoginPage()) {
                window.location.href = getLoginUrl();
            }
            return false;
        }

        // Get user details
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
        
        if (userError) throw userError;

        console.log('User authenticated:', user.email);
        // Update user name in header
        updateUserName(user.email);

        // If on login page and authenticated, redirect to dashboard
        if (isLoginPage()) {
            window.location.href = getDashboardUrl();
        }

        return true;
    } catch (error) {
        console.error('Auth error:', error);
        // Redirect to login page on auth error
        if (!isLoginPage()) {
            window.location.href = getLoginUrl();
        }
        return false;
    }
}

// Handle logout
async function handleLogout() {
    try {
        const supabaseClient = await waitForSupabase();
        const { error } = await supabaseClient.auth.signOut();
        if (error) throw error;
        window.location.href = getLoginUrl();
    } catch (error) {
        console.error('Error logging out:', error);
        alert('Error logging out. Please try again.');
    }
}

// Handle login form submission
async function handleLogin(e) {
    if (e) e.preventDefault();
    
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const errorMessage = document.getElementById('errorMessage');
    
    try {
        const supabaseClient = await waitForSupabase();
        const { data, error } = await supabaseClient.auth.signInWithPassword({
            email,
            password
        });

        if (error) throw error;

        if (data.session) {
            window.location.href = getDashboardUrl();
        } else {
            throw new Error('No session created after login');
        }
    } catch (error) {
        console.error('Login error:', error);
        if (errorMessage) {
            errorMessage.style.display = 'block';
            errorMessage.textContent = error.message || 'Failed to log in. Please check your credentials and try again.';
        } else {
            alert('Failed to log in. Please check your credentials and try again.');
        }
    }
}

// Set up event listeners when DOM is loaded
document.addEventListener('DOMContentLoaded', async () => {
    console.log('DOM Content Loaded');
    
    // Wait for Supabase to be initialized before checking auth
    await waitForSupabase();
    
    // Check authentication status
    await checkAuth();
    
    // Set up login form listener if on login page
    const loginForm = document.getElementById('loginForm');
    console.log('Login form found:', !!loginForm);
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }
    
    // Set up logout button listener
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', handleLogout);
    }
}); 