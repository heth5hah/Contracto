// Wait for Supabase to be initialized
function waitForSupabase() {
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

// Load dashboard stats (using dummy data for now)
async function loadDashboardStats() {
    try {
        // Dummy data for demonstration
        const stats = {
            total_quotes: 156,
            accepted_quotes: 89,
            pending_quotes: 23,
            total_users: 47
        };

        document.getElementById('totalQuotes').textContent = stats.total_quotes;
        document.getElementById('acceptedQuotes').textContent = stats.accepted_quotes;
        document.getElementById('pendingQuotes').textContent = stats.pending_quotes;
        document.getElementById('totalUsers').textContent = stats.total_users;
    } catch (error) {
        console.error('Error loading dashboard stats:', error);
        // Fallback to default values
        document.getElementById('totalQuotes').textContent = '156';
        document.getElementById('acceptedQuotes').textContent = '89';
        document.getElementById('pendingQuotes').textContent = '23';
        document.getElementById('totalUsers').textContent = '47';
    }
}

// Load recent quotations (using dummy data for now)
async function loadRecentQuotations() {
    try {
        // Dummy data for demonstration
        const quotations = [
            { quotation_number: 'QT-2024-001', customer_name: 'ABC Construction', total_amount: 125000, status: 'Pending', created_at: new Date().toISOString() },
            { quotation_number: 'QT-2024-002', customer_name: 'XYZ Builders', total_amount: 89000, status: 'Accepted', created_at: new Date(Date.now() - 86400000).toISOString() },
            { quotation_number: 'QT-2024-003', customer_name: 'PQR Projects', total_amount: 156000, status: 'Pending', created_at: new Date(Date.now() - 172800000).toISOString() },
            { quotation_number: 'QT-2024-004', customer_name: 'LMN Infrastructure', total_amount: 203000, status: 'Accepted', created_at: new Date(Date.now() - 259200000).toISOString() },
            { quotation_number: 'QT-2024-005', customer_name: 'RST Developers', total_amount: 98000, status: 'Rejected', created_at: new Date(Date.now() - 345600000).toISOString() }
        ];

        const tableBody = document.getElementById('recentQuotesTable');
        if (tableBody) {
            tableBody.innerHTML = '';

            quotations.forEach(quotation => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${quotation.quotation_number}</td>
                    <td>${quotation.customer_name}</td>
                    <td>₹${quotation.total_amount.toLocaleString()}</td>
                    <td><span class="status-badge ${quotation.status.toLowerCase()}">${quotation.status}</span></td>
                    <td>${formatDate(quotation.created_at)}</td>
                `;
                tableBody.appendChild(row);
            });
        }
    } catch (error) {
        console.error('Error loading recent quotations:', error);
    }
}

// Load recent users (using dummy data for now)
async function loadRecentUsers() {
    try {
        // Dummy data for demonstration
        const users = [
            { name: 'Rajesh Construction', pan: 'ABCDE1234F', business_type: 'Construction', created_at: new Date().toISOString() },
            { name: 'Priya Builders', pan: 'FGHIJ5678K', business_type: 'Building', created_at: new Date(Date.now() - 86400000).toISOString() },
            { name: 'Mumbai Infrastructure', pan: 'LMNOP9012Q', business_type: 'Infrastructure', created_at: new Date(Date.now() - 172800000).toISOString() },
            { name: 'Delhi Developers', pan: 'RSTUV3456W', business_type: 'Development', created_at: new Date(Date.now() - 259200000).toISOString() },
            { name: 'Chennai Contractors', pan: 'XYZAB7890C', business_type: 'Contracting', created_at: new Date(Date.now() - 345600000).toISOString() }
        ];

        const tableBody = document.getElementById('recentUsersTable');
        if (tableBody) {
            tableBody.innerHTML = '';

            users.forEach(user => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${user.name}</td>
                    <td>${user.pan}</td>
                    <td>${user.business_type}</td>
                    <td>${formatDate(user.created_at)}</td>
                `;
                tableBody.appendChild(row);
            });
        }
    } catch (error) {
        console.error('Error loading recent users:', error);
    }
} 

// Helper function to format currency
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR'
    }).format(amount);
}

// Helper function to format date
function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Chart instances
let revenueChart = null;
let quotesChart = null;

// Initialize charts with dark mode support
function initializeCharts() {
    const isDarkMode = document.body.classList.contains('dark-mode');
    
    // Chart.js default font settings for dark mode
    Chart.defaults.color = isDarkMode ? '#E0E0E0' : '#374151';
    Chart.defaults.borderColor = isDarkMode ? '#333333' : '#E5E7EB';
    Chart.defaults.backgroundColor = isDarkMode ? '#1E1E1E' : '#FFFFFF';

    // Revenue Chart
    const revenueCtx = document.getElementById('revenueChart');
    if (revenueCtx) {
        revenueChart = new Chart(revenueCtx, {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                datasets: [{
                    label: 'Revenue (₹)',
                    data: [125000, 180000, 160000, 220000, 185000, 240000],
                    borderColor: '#667eea',
                    backgroundColor: 'rgba(102, 126, 234, 0.1)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.4,
                    pointBackgroundColor: '#667eea',
                    pointBorderColor: '#FFFFFF',
                    pointBorderWidth: 2,
                    pointRadius: 6,
                    pointHoverRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                aspectRatio: 3.5,
                interaction: {
                    intersect: false,
                },
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: isDarkMode ? '#333333' : '#E5E7EB'
                        },
                        ticks: {
                            callback: function(value) {
                                return '₹' + (value / 1000) + 'K';
                            }
                        }
                    },
                    x: {
                        grid: {
                            color: isDarkMode ? '#333333' : '#E5E7EB'
                        }
                    }
                },
                animation: {
                    duration: 2000,
                    easing: 'easeInOutQuart'
                }
            }
        });
    }

    // Quotes Chart
    const quotesCtx = document.getElementById('quotesChart');
    if (quotesCtx) {
        quotesChart = new Chart(quotesCtx, {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                datasets: [{
                    label: 'Total Quotes',
                    data: [45, 62, 58, 75, 68, 82],
                    borderColor: '#764ba2',
                    backgroundColor: 'rgba(118, 75, 162, 0.1)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.4,
                    pointBackgroundColor: '#764ba2',
                    pointBorderColor: '#FFFFFF',
                    pointBorderWidth: 2,
                    pointRadius: 6,
                    pointHoverRadius: 8
                }, {
                    label: 'Accepted Quotes',
                    data: [35, 48, 42, 58, 52, 65],
                    borderColor: '#2E7D32',
                    backgroundColor: 'rgba(46, 125, 50, 0.1)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.4,
                    pointBackgroundColor: '#2E7D32',
                    pointBorderColor: '#FFFFFF',
                    pointBorderWidth: 2,
                    pointRadius: 6,
                    pointHoverRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                aspectRatio: 3.5,
                interaction: {
                    intersect: false,
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        align: 'end',
                        labels: {
                            boxWidth: 12,
                            padding: 20,
                            font: {
                                size: 11
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: isDarkMode ? '#333333' : '#E5E7EB'
                        }
                    },
                    x: {
                        grid: {
                            color: isDarkMode ? '#333333' : '#E5E7EB'
                        }
                    }
                },
                animation: {
                    duration: 2000,
                    easing: 'easeInOutQuart'
                }
            }
        });
    }
}

// Update charts when theme changes
function updateChartsTheme() {
    const isDarkMode = document.body.classList.contains('dark-mode');
    
    Chart.defaults.color = isDarkMode ? '#E0E0E0' : '#374151';
    Chart.defaults.borderColor = isDarkMode ? '#333333' : '#E5E7EB';
    
    // Update existing charts
    if (revenueChart) {
        revenueChart.options.scales.y.grid.color = isDarkMode ? '#333333' : '#E5E7EB';
        revenueChart.options.scales.x.grid.color = isDarkMode ? '#333333' : '#E5E7EB';
        revenueChart.update();
    }
    
    if (quotesChart) {
        quotesChart.options.scales.y.grid.color = isDarkMode ? '#333333' : '#E5E7EB';
        quotesChart.options.scales.x.grid.color = isDarkMode ? '#333333' : '#E5E7EB';
        quotesChart.update();
    }
}

// Listen for theme changes
document.addEventListener('themeChanged', updateChartsTheme);

// Load data when the page loads
document.addEventListener('DOMContentLoaded', async () => {
    try {
        console.log('Initializing dashboard...');
        // Wait for auth to be ready
        await waitForSupabase();
        
        // Load dashboard data
        await loadDashboardStats();
        await loadRecentQuotations();
        await loadRecentUsers();
        
        // Initialize charts after a small delay to ensure Chart.js is loaded
        setTimeout(() => {
            if (typeof Chart !== 'undefined') {
                console.log('Initializing charts...');
                initializeCharts();
            } else {
                console.error('Chart.js not loaded');
            }
        }, 300);
    } catch (error) {
        console.error('Error initializing dashboard:', error);
    }
}); 