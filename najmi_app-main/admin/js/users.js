let currentUserId = null;

// Load users when the page loads
document.addEventListener('DOMContentLoaded', async () => {
    await loadUsers();
    setupSearchListener();
});

// Setup search functionality
function setupSearchListener() {
    const searchInput = document.getElementById('searchUsers');
    let debounceTimer;

    searchInput.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            const searchTerm = e.target.value.toLowerCase();
            filterUsers(searchTerm);
        }, 300);
    });
}

// Filter users based on search term
function filterUsers(searchTerm) {
    const rows = document.querySelectorAll('#usersTable tr');
    rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(searchTerm) ? '' : 'none';
    });
}

// Load all users (using dummy data for development)
async function loadUsers() {
    try {
        // Dummy data for development
        const users = [
            {
                id: 1,
                name: 'ABC Construction',
                mobile: '+91 98765 43210',
                email: 'contact@abcconstruction.com',
                company: 'ABC Construction Pvt Ltd',
                pan: 'ABCDE1234F',
                business_type: 'Construction',
                created_at: new Date().toISOString(),
                credit_limit: 100000,
                total_quotes: 15,
                accepted_quotes: 8,
                pending_quotes: 4
            },
            {
                id: 2,
                name: 'XYZ Builders',
                mobile: '+91 87654 32109',
                email: 'info@xyzbuilders.com',
                company: 'XYZ Builders Ltd',
                pan: 'FGHIJ5678K',
                business_type: 'Building',
                created_at: new Date(Date.now() - 86400000).toISOString(),
                credit_limit: 150000,
                total_quotes: 12,
                accepted_quotes: 6,
                pending_quotes: 3
            },
            {
                id: 3,
                name: 'PQR Infrastructure',
                mobile: '+91 76543 21098',
                email: 'admin@pqrinfra.com',
                company: 'PQR Infrastructure',
                pan: 'LMNOP9012Q',
                business_type: 'Infrastructure',
                created_at: new Date(Date.now() - 172800000).toISOString(),
                credit_limit: 200000,
                total_quotes: 20,
                accepted_quotes: 12,
                pending_quotes: 5
            }
        ];

        const tableBody = document.getElementById('usersTable');
        if (!tableBody) {
            console.error('Users table not found');
            return;
        }

        tableBody.innerHTML = '';
        users.forEach(user => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${user.name || '-'}</td>
                <td>${user.mobile || '-'}</td>
                <td>${user.email || '-'}</td>
                <td>${user.company || '-'}</td>
                <td>${user.pan || '-'}</td>
                <td>${user.business_type || '-'}</td>
                <td>₹${(user.credit_limit || 0).toFixed(2)}</td>
                <td>${user.total_quotes || 0}</td>
                <td>${user.accepted_quotes || 0}</td>
                <td>${user.pending_quotes || 0}</td>
                <td>${formatDate(user.created_at)}</td>
                <td>
                    <button onclick="editUser(${user.id})" class="btn-icon">
                        <i class="ri-edit-line"></i>
                    </button>
                    <button onclick="deleteUser(${user.id})" class="btn-icon delete">
                        <i class="ri-delete-bin-line"></i>
                    </button>
                </td>
            `;
            tableBody.appendChild(row);
        });
    } catch (error) {
        console.error('Error loading users:', error);
    }
}

// Helper function to format date
function formatDate(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Open modal for adding a new user
function openAddUserModal() {
    currentUserId = null;
    document.getElementById('modalTitle').textContent = 'Add User';
    document.getElementById('userForm').reset();
    document.getElementById('userModal').style.display = 'block';
}

// Open modal for editing an existing user
async function editUser(userId) {
    try {
        const { data: user, error } = await supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .single();

        if (error) throw error;

        currentUserId = userId;
        document.getElementById('modalTitle').textContent = 'Edit User';
        document.getElementById('userName').value = user.name;
        document.getElementById('userMobile').value = user.mobile;
        document.getElementById('userEmail').value = user.email || '';
        document.getElementById('userPan').value = user.pan;
        document.getElementById('userGst').value = user.gst_number || '';
        document.getElementById('creditLimit').value = user.credit_limit;
        document.getElementById('userStatus').value = user.status;
        document.getElementById('userModal').style.display = 'block';
    } catch (error) {
        console.error('Error loading user:', error);
        alert('Failed to load user details. Please try again.');
    }
}

// Close the user modal
function closeUserModal() {
    document.getElementById('userModal').style.display = 'none';
    document.getElementById('userForm').reset();
    currentUserId = null;
}

// Handle form submission for adding/editing users
document.getElementById('userForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const userData = {
        name: document.getElementById('userName').value,
        mobile: document.getElementById('userMobile').value,
        email: document.getElementById('userEmail').value || null,
        pan: document.getElementById('userPan').value,
        gst_number: document.getElementById('userGst').value || null,
        credit_limit: parseFloat(document.getElementById('creditLimit').value),
        status: document.getElementById('userStatus').value,
        role: 'customer' // Default role for users created from admin panel
    };

    try {
        let error;
        if (currentUserId) {
            // Update existing user
            const { error: updateError } = await supabase
                .from('users')
                .update(userData)
                .eq('id', currentUserId);
            error = updateError;
        } else {
            // Add new user with a default password
            userData.password_hash = 'default_password_hash'; // This should be properly hashed in production
            const { error: insertError } = await supabase
                .from('users')
                .insert([userData]);
            error = insertError;
        }

        if (error) throw error;

        closeUserModal();
        await loadUsers();
        alert(`User ${currentUserId ? 'updated' : 'added'} successfully!`);
    } catch (error) {
        console.error('Error saving user:', error);
        alert('Failed to save user. Please try again.');
    }
});

// Delete a user
async function deleteUser(userId) {
    if (!confirm('Are you sure you want to delete this user?')) return;

    try {
        const { error } = await supabase
            .from('users')
            .delete()
            .eq('id', userId);

        if (error) throw error;

        await loadUsers();
        alert('User deleted successfully!');
    } catch (error) {
        console.error('Error deleting user:', error);
        alert('Failed to delete user. Please try again.');
    }
} 