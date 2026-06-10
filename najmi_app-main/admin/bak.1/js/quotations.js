// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// DOM Elements
const searchInput = document.getElementById('searchQuotes');
const statusFilter = document.getElementById('statusFilter');
const quoteRequestsTable = document.getElementById('quoteRequestsTable');
const quoteRequestModal = document.getElementById('quoteRequestModal');
const generateQuoteForm = document.getElementById('generateQuoteForm');

let currentQuoteRequest = null;

// Sample quote requests data for demonstration
const sampleQuoteRequests = [
    {
        id: 'QR-2024-001',
        status: 'pending',
        created_at: '2024-01-15T10:30:00Z',
        delivery_address: '123 Business Park, Industrial Area, Mumbai, Maharashtra 400001',
        notes: 'Urgent requirement for ongoing construction project. Need quality products with fast delivery.',
        credit_terms: '30 days',
        users: {
            name: 'Ahmed Construction Ltd.',
            mobile: '+91 98765 43210',
            email: 'ahmed@construction.com',
            gst_number: '27ABCDE1234F1Z5'
        },
        quote_request_items: [
            {
                id: 'item-1',
                product_id: 'prod-1',
                quantity: 10,
                unit: 'units',
                products: { name: 'Industrial Switch Board Pro' }
            },
            {
                id: 'item-2',
                product_id: 'prod-2',
                quantity: 25,
                unit: 'units',
                products: { name: 'LED Panel Light 40W' }
            },
            {
                id: 'item-3',
                product_id: 'prod-3',
                quantity: 15,
                unit: 'units',
                products: { name: 'Circuit Breaker 32A' }
            }
        ]
    },
    {
        id: 'QR-2024-002',
        status: 'quoted',
        created_at: '2024-01-12T14:15:00Z',
        delivery_address: '456 Industrial Zone, Sector 5, Noida, Uttar Pradesh 201301',
        notes: 'Looking for bulk pricing. This is a repeat customer with good payment history.',
        credit_terms: '45 days',
        users: {
            name: 'Modern Builders Pvt Ltd',
            mobile: '+91 87654 32109',
            email: 'info@modernbuilders.com',
            gst_number: '09FGHIJ5678K2L3'
        },
        quote_request_items: [
            {
                id: 'item-4',
                product_id: 'prod-4',
                quantity: 5,
                unit: 'units',
                products: { name: 'Professional Power Drill' }
            },
            {
                id: 'item-5',
                product_id: 'prod-5',
                quantity: 20,
                unit: 'sets',
                products: { name: 'PVC Pipe Set (Various Sizes)' }
            },
            {
                id: 'item-6',
                product_id: 'prod-6',
                quantity: 20,
                unit: 'units',
                products: { name: 'Safety Helmet Pro' }
            }
        ]
    },
    {
        id: 'QR-2024-003',
        status: 'pending',
        created_at: '2024-01-18T09:45:00Z',
        delivery_address: '789 Technology Park, Whitefield, Bangalore, Karnataka 560066',
        notes: 'New customer referral from Ahmed Construction. Need competitive pricing.',
        credit_terms: '60 days',
        users: {
            name: 'Elite Contractors',
            mobile: '+91 76543 21098',
            email: 'procurement@elitecontractors.com',
            gst_number: '29KLMNO9012P3Q4'
        },
        quote_request_items: [
            {
                id: 'item-7',
                product_id: 'prod-7',
                quantity: 2,
                unit: 'units',
                products: { name: 'Water Pump 1HP' }
            },
            {
                id: 'item-8',
                product_id: 'prod-8',
                quantity: 10,
                unit: 'kits',
                products: { name: 'Brass Fittings Kit' }
            }
        ]
    },
    {
        id: 'QR-2024-004',
        status: 'accepted',
        created_at: '2024-01-10T16:20:00Z',
        delivery_address: '321 Manufacturing Hub, MIDC Area, Pune, Maharashtra 411019',
        notes: 'Large order for new facility setup. Payment will be made in advance.',
        credit_terms: '15 days',
        users: {
            name: 'Skyline Infrastructure',
            mobile: '+91 65432 10987',
            email: 'orders@skylineinfra.com',
            gst_number: '27PQRST3456U7V8'
        },
        quote_request_items: [
            {
                id: 'item-9',
                product_id: 'prod-9',
                quantity: 20,
                unit: 'pieces',
                products: { name: 'Steel Rods TMT 12mm' }
            },
            {
                id: 'item-10',
                product_id: 'prod-10',
                quantity: 25,
                unit: 'bags',
                products: { name: 'Cement Bags (50kg)' }
            }
        ]
    },
    {
        id: 'QR-2024-005',
        status: 'pending',
        created_at: '2024-01-20T11:30:00Z',
        delivery_address: '567 Business District, Cyber City, Gurgaon, Haryana 122002',
        notes: 'Follow-up required for approval. Customer is evaluating multiple suppliers.',
        credit_terms: '30 days',
        users: {
            name: 'Prime Developers',
            mobile: '+91 54321 09876',
            email: 'purchase@primedevelopers.com',
            gst_number: '06UVWXY7890Z1A2'
        },
        quote_request_items: [
            {
                id: 'item-11',
                product_id: 'prod-11',
                quantity: 12,
                unit: 'units',
                products: { name: 'Heavy Duty Hammer' }
            },
            {
                id: 'item-12',
                product_id: 'prod-12',
                quantity: 30,
                unit: 'sets',
                products: { name: 'Stainless Steel Bolts Set' }
            },
            {
                id: 'item-13',
                product_id: 'prod-13',
                quantity: 35,
                unit: 'pairs',
                products: { name: 'Safety Gloves Industrial' }
            }
        ]
    }
];

// Load quote requests
async function loadQuoteRequests() {
    try {
        // For demo purposes, use sample data
        // In real implementation, this would fetch from Supabase
        let requests = [...sampleQuoteRequests];

        // Apply status filter
        if (statusFilter.value !== 'all') {
            requests = requests.filter(request => request.status === statusFilter.value);
        }

        // Apply search filter
        const searchTerm = searchInput.value.toLowerCase();
        if (searchTerm) {
            requests = requests.filter(request => 
                request.users.name.toLowerCase().includes(searchTerm) ||
                request.id.toLowerCase().includes(searchTerm) ||
                request.users.email.toLowerCase().includes(searchTerm)
            );
        }

        quoteRequestsTable.innerHTML = requests.map(request => {
            const statusColors = {
                pending: 'warning',
                quoted: 'info', 
                accepted: 'success',
                rejected: 'danger',
                expired: 'secondary'
            };

            return `
                <tr>
                    <td><strong>${request.id}</strong></td>
                    <td>
                        <div class="customer-info">
                            <strong>${request.users.name}</strong><br>
                            <small class="text-muted">${request.users.email}</small>
                        </div>
                    </td>
                    <td>
                        <span class="badge badge-light">
                            ${request.quote_request_items.length} item${request.quote_request_items.length > 1 ? 's' : ''}
                        </span>
                    </td>
                    <td>
                        <span class="status-badge status-${statusColors[request.status]}">
                            ${request.status.charAt(0).toUpperCase() + request.status.slice(1)}
                        </span>
                    </td>
                    <td>
                        <div class="date-info">
                            ${new Date(request.created_at).toLocaleDateString('en-IN', {
                                day: '2-digit',
                                month: 'short',
                                year: 'numeric'
                            })}<br>
                            <small class="text-muted">${new Date(request.created_at).toLocaleTimeString('en-IN', {
                                hour: '2-digit',
                                minute: '2-digit'
                            })}</small>
                        </div>
                    </td>
                    <td>
                        <div class="action-buttons">
                            <button onclick="viewQuoteRequest('${request.id}')" class="btn-icon btn-primary" title="View Details">
                                <i class="ri-eye-line"></i>
                            </button>
                            ${request.status === 'pending' ? `
                                <button onclick="generateQuote('${request.id}')" class="btn-icon btn-success" title="Generate Quote">
                                    <i class="ri-file-text-line"></i>
                                </button>
                            ` : ''}
                        </div>
                    </td>
                </tr>
            `;
        }).join('');

        // Update stats
        updateStats(requests);
    } catch (error) {
        console.error('Error loading quote requests:', error);
        alert('Failed to load quote requests. Please try again.');
    }
}

// Update dashboard stats
function updateStats(requests) {
    const stats = {
        total: requests.length,
        pending: requests.filter(r => r.status === 'pending').length,
        quoted: requests.filter(r => r.status === 'quoted').length,
        accepted: requests.filter(r => r.status === 'accepted').length
    };

    // Update stats display if elements exist
    document.querySelectorAll('[data-stat]').forEach(el => {
        const statType = el.dataset.stat;
        if (stats[statType] !== undefined) {
            el.textContent = stats[statType];
        }
    });
}

// View quote request details
async function viewQuoteRequest(requestId) {
    try {
        const request = sampleQuoteRequests.find(r => r.id === requestId);
        if (!request) throw new Error('Quote request not found');

        currentQuoteRequest = request;

        // Fill customer information
        document.getElementById('customerName').textContent = request.users.name;
        document.getElementById('customerMobile').textContent = request.users.mobile;
        document.getElementById('customerEmail').textContent = request.users.email || 'N/A';
        document.getElementById('customerGST').textContent = request.users.gst_number || 'N/A';
        document.getElementById('deliveryAddress').textContent = request.delivery_address;
        document.getElementById('customerNotes').textContent = request.notes || 'No notes provided';

        // Fill requested items table
        document.getElementById('requestedItemsTable').innerHTML = request.quote_request_items.map(item => `
            <tr>
                <td>
                    <strong>${item.products.name}</strong><br>
                    <small class="text-muted">Product ID: ${item.product_id}</small>
                </td>
                <td><strong>${item.quantity}</strong></td>
                <td>${item.unit}</td>
            </tr>
        `).join('');

        // Pre-fill quote items with suggested prices
        const suggestedPrices = {
            'prod-1': 1200, 'prod-2': 850, 'prod-3': 450, 'prod-4': 2500, 'prod-5': 450,
            'prod-6': 350, 'prod-7': 3500, 'prod-8': 890, 'prod-9': 2800, 'prod-10': 450,
            'prod-11': 800, 'prod-12': 560, 'prod-13': 180
        };

        document.getElementById('quoteItemsTable').innerHTML = request.quote_request_items.map(item => {
            const suggestedPrice = suggestedPrices[item.product_id] || 100;
            return `
                <tr>
                    <td>
                        <strong>${item.products.name}</strong><br>
                        <small class="text-muted">Product ID: ${item.product_id}</small>
                    </td>
                    <td><strong>${item.quantity}</strong></td>
                    <td>${item.unit}</td>
                    <td>
                        <div class="price-input-group">
                            <span class="currency">₹</span>
                            <input type="number" 
                                   class="unit-price form-control" 
                                   data-item-id="${item.id}"
                                   data-quantity="${item.quantity}"
                                   value="${suggestedPrice}"
                                   min="0" 
                                   step="0.01" 
                                   required 
                                   onchange="updateTotals()">
                        </div>
                    </td>
                    <td class="item-total font-weight-bold">₹${(item.quantity * suggestedPrice).toFixed(2)}</td>
                </tr>
            `;
        }).join('');

        // Set default payment terms
        document.getElementById('paymentTerms').value = `Credit Terms: ${request.credit_terms}\nPayment due within ${request.credit_terms} from invoice date.\nLate payments may incur additional charges.`;
        
        // Set default bank details
        document.getElementById('bankName').value = 'State Bank of India';
        document.getElementById('accountNumber').value = '1234567890123456';
        document.getElementById('ifscCode').value = 'SBIN0001234';
        document.getElementById('upiId').value = 'contracto@paytm';

        // Calculate initial totals
        updateTotals();

        quoteRequestModal.style.display = 'block';
    } catch (error) {
        console.error('Error loading quote request details:', error);
        alert('Failed to load quote request details. Please try again.');
    }
}

// Generate quote shortcut
function generateQuote(requestId) {
    viewQuoteRequest(requestId);
    // Scroll to quote form
    setTimeout(() => {
        document.querySelector('.quote-form').scrollIntoView({
            behavior: 'smooth'
        });
    }, 500);
}

// Update totals when unit prices change
function updateTotals() {
    const rows = document.getElementById('quoteItemsTable').getElementsByTagName('tr');
    let subtotal = 0;

    for (let row of rows) {
        const quantityCell = row.cells[1];
        const unitPriceInput = row.querySelector('.unit-price');
        const itemTotalCell = row.querySelector('.item-total');
        
        if (quantityCell && unitPriceInput && itemTotalCell) {
            const quantity = parseFloat(quantityCell.textContent);
            const unitPrice = parseFloat(unitPriceInput.value) || 0;
            const total = quantity * unitPrice;
            
            itemTotalCell.textContent = `₹${total.toFixed(2)}`;
            subtotal += total;
        }
    }

    const tax = subtotal * 0.18; // 18% GST
    const grandTotal = subtotal + tax;

    document.getElementById('subtotal').textContent = subtotal.toFixed(2);
    document.getElementById('tax').textContent = tax.toFixed(2);
    document.getElementById('grandTotal').textContent = grandTotal.toFixed(2);
}

// Generate and send quote
generateQuoteForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    if (!currentQuoteRequest) {
        alert('No quote request selected');
        return;
    }

    try {
        // Show loading state
        const submitBtn = e.target.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Generating Quote...';
        submitBtn.disabled = true;

        // Collect quote items
        const quoteItems = [];
        const rows = document.getElementById('quoteItemsTable').getElementsByTagName('tr');
        let subtotal = 0;

        for (let row of rows) {
            const unitPriceInput = row.querySelector('.unit-price');
            const itemId = unitPriceInput.dataset.itemId;
            const quantity = parseFloat(unitPriceInput.dataset.quantity);
            const requestItem = currentQuoteRequest.quote_request_items.find(item => item.id === itemId);
            const unitPrice = parseFloat(unitPriceInput.value);
            const total = quantity * unitPrice;

            quoteItems.push({
                product_id: requestItem.product_id,
                product_name: requestItem.products.name,
                quantity: quantity,
                unit: requestItem.unit,
                unit_price: unitPrice,
                total_price: total
            });

            subtotal += total;
        }

        const tax = subtotal * 0.18;
        const grandTotal = subtotal + tax;

        // Simulate quote generation
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Update request status
        const requestIndex = sampleQuoteRequests.findIndex(r => r.id === currentQuoteRequest.id);
        if (requestIndex !== -1) {
            sampleQuoteRequests[requestIndex].status = 'quoted';
        }

        // Show success message
        alert(`Quote generated successfully!\n\nQuote ID: QT-${currentQuoteRequest.id}\nTotal Amount: ₹${grandTotal.toFixed(2)}\n\nQuote has been sent to ${currentQuoteRequest.users.email}`);

        // Close modal and refresh list
        closeQuoteModal();
        loadQuoteRequests();

    } catch (error) {
        console.error('Error generating quote:', error);
        alert('Failed to generate quote. Please try again.');
    } finally {
        // Reset button state
        const submitBtn = e.target.querySelector('button[type="submit"]');
        submitBtn.textContent = originalText;
        submitBtn.disabled = false;
    }
});

// Close modal
function closeQuoteModal() {
    quoteRequestModal.style.display = 'none';
    currentQuoteRequest = null;
    generateQuoteForm.reset();
}

// Event listeners
document.addEventListener('DOMContentLoaded', () => {
    loadQuoteRequests();
});

statusFilter.addEventListener('change', loadQuoteRequests);
searchInput.addEventListener('input', debounce(loadQuoteRequests, 300));

// Utility function for debouncing
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Close modal when clicking outside
window.addEventListener('click', (e) => {
    if (e.target === quoteRequestModal) {
        closeQuoteModal();
    }
});

// Add some CSS styles dynamically for better presentation
const style = document.createElement('style');
style.textContent = `
    .customer-info strong {
        color: #1e293b;
        font-weight: 600;
    }
    
    .date-info {
        text-align: center;
    }
    
    .action-buttons {
        display: flex;
        gap: 8px;
        justify-content: center;
    }
    
    .btn-icon {
        width: 36px;
        height: 36px;
        border-radius: 8px;
        border: none;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        transition: all 0.2s ease;
    }
    
    .btn-primary {
        background-color: #3b82f6;
        color: white;
    }
    
    .btn-success {
        background-color: #10b981;
        color: white;
    }
    
    .btn-icon:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    }
    
    .status-badge {
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 12px;
        font-weight: 600;
        text-transform: uppercase;
    }
    
    .status-warning {
        background-color: #fef3c7;
        color: #d97706;
    }
    
    .status-info {
        background-color: #dbeafe;
        color: #2563eb;
    }
    
    .status-success {
        background-color: #d1fae5;
        color: #059669;
    }
    
    .status-danger {
        background-color: #fee2e2;
        color: #dc2626;
    }
    
    .status-secondary {
        background-color: #f1f5f9;
        color: #64748b;
    }
    
    .badge {
        padding: 2px 8px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: 500;
    }
    
    .badge-light {
        background-color: #f8fafc;
        color: #475569;
        border: 1px solid #e2e8f0;
    }
    
    .price-input-group {
        position: relative;
        display: flex;
        align-items: center;
    }
    
    .currency {
        position: absolute;
        left: 12px;
        color: #64748b;
        font-weight: 500;
        z-index: 1;
    }
    
    .price-input-group input {
        padding-left: 28px;
    }
    
    .text-muted {
        color: #64748b !important;
        font-size: 12px;
    }
    
    .font-weight-bold {
        font-weight: 600 !important;
    }
`;
document.head.appendChild(style); 