// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// DOM Elements
const searchInput = document.getElementById('searchQuotes');
const statusFilter = document.getElementById('statusFilter');
const quoteRequestsTable = document.getElementById('quoteRequestsTable');
const quoteRequestModal = document.getElementById('quoteRequestModal');
const generateQuoteForm = document.getElementById('generateQuoteForm');

let currentQuoteRequest = null;

// Load quote requests from database
async function loadQuoteRequests() {
    try {
        // Show loading state
        quoteRequestsTable.innerHTML = '<tr><td colspan="6" class="text-center">Loading...</td></tr>';

        // Fetch quote requests from database
        const { data: quoteRequests, error } = await supabase
            .from('quote_requests')
            .select(`
                *,
                quote_request_items (*),
                users:user_id (email, user_metadata),
                quotes (*, quote_items (*))
            `)
            .order('created_at', { ascending: false });

        if (error) throw error;

        let requests = quoteRequests || [];

        // Apply status filter
        if (statusFilter.value !== 'all') {
            requests = requests.filter(request => request.status === statusFilter.value);
        }

        // Apply search filter
        const searchTerm = searchInput.value.toLowerCase();
        if (searchTerm) {
            requests = requests.filter(request =>
                request.product_name.toLowerCase().includes(searchTerm) ||
                request.id.toLowerCase().includes(searchTerm) ||
                (request.users?.email?.toLowerCase().includes(searchTerm) || false)
            );
        }

        if (requests.length === 0) {
            quoteRequestsTable.innerHTML = '<tr><td colspan="6" class="text-center">No quote requests found</td></tr>';
            return;
        }

        quoteRequestsTable.innerHTML = requests.map(request => {
            const statusColors = {
                pending: 'warning',
                quoted: 'info',
                accepted: 'success',
                rejected: 'danger',
                expired: 'secondary'
            };

            const customerName = request.users?.user_metadata?.full_name ||
                request.users?.email?.split('@')[0] ||
                'Unknown Customer';
            const customerEmail = request.users?.email || 'No email';

            const brandBadge = request.brand_id ? `<span class="badge badge-info mr-1">${request.brand_id}</span>` : '';
            const itemsCount = request.quote_request_items?.length || 0;

            return `
                <tr>
                    <td><strong>${request.id.substring(0, 8)}</strong></td>
                    <td>
                        <div class="customer-info">
                            <strong>${customerName}</strong><br>
                            <small class="text-muted">${customerEmail}</small>
                        </div>
                    </td>
                    <td>
                        <div class="items-summary">
                            ${brandBadge}
                            <span class="badge badge-light">
                                ${itemsCount} item${itemsCount !== 1 ? 's' : ''}
                            </span>
                        </div>
                    </td>
                    <td>
                        <span class="status-badge status-${statusColors[request.status] || 'secondary'}">
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
        quoteRequestsTable.innerHTML = '<tr><td colspan="6" class="text-center text-danger">Error loading quote requests</td></tr>';
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
        // Fetch quote request details from database
        const { data: request, error } = await supabase
            .from('quote_requests')
            .select(`
                *,
                quote_request_items (*),
                users:user_id (email, user_metadata),
                quotes (*, quote_items (*))
            `)
            .eq('id', requestId)
            .single();

        if (error) throw error;
        if (!request) throw new Error('Quote request not found');

        currentQuoteRequest = request;

        // Fill customer information
        const customerName = request.users?.user_metadata?.full_name ||
            request.users?.email?.split('@')[0] ||
            'Unknown Customer';
        const customerEmail = request.users?.email || 'No email';

        document.getElementById('customerName').textContent = customerName;
        document.getElementById('customerMobile').textContent = 'N/A'; // Not stored in current schema
        document.getElementById('customerEmail').textContent = customerEmail;
        document.getElementById('customerGST').textContent = 'N/A'; // Not stored in current schema
        document.getElementById('deliveryAddress').textContent = 'N/A'; // Not stored in current schema
        document.getElementById('customerNotes').textContent = request.notes || 'No notes provided';

        // Fill requested items table
        document.getElementById('requestedItemsTable').innerHTML = (request.quote_request_items || []).map(item => `
            <tr>
                <td>
                    <strong>${item.quality_option_name || request.product_name}</strong><br>
                    <small class="text-muted">${item.quality_option_id ? `Option: ${item.quality_option_id}` : 'Single Product'}</small>
                </td>
                <td><span class="badge badge-info">${item.brand_id || request.brand_id || 'N/A'}</span></td>
                <td><strong>${item.quantity}</strong></td>
                <td>${item.unit}</td>
                <td><small>${item.notes || 'No item notes'}</small></td>
            </tr>
        `).join('');

        // Pricing Breakdown Visibility Logic
        const pricedQuote = request.quotes && request.quotes.length > 0 ? request.quotes[0] : null;
        const pricedItems = pricedQuote ? (pricedQuote.quote_items || []) : [];

        // Add a section for the breakdown if it exists
        let breakdownHtml = '';
        if (pricedItems.length > 0) {
            breakdownHtml = `
                <div class="pricing-breakdown">
                    <h3>Priced Items Breakdown</h3>
                    <table class="items-table">
                        <thead>
                            <tr>
                                <th>Item</th>
                                <th>Quantity</th>
                                <th>Unit Price</th>
                                <th>Total</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${pricedItems.map(item => `
                                <tr>
                                    <td>${item.quality_option_name || 'Item'}</td>
                                    <td>${item.quantity} ${item.unit || ''}</td>
                                    <td>₹${item.unit_price.toFixed(2)}</td>
                                    <td>₹${item.total_price.toFixed(2)}</td>
                                </tr>
                            `).join('')}
                        </tbody>
                        <tfoot>
                            <tr>
                                <td colspan="3" class="text-right"><strong>Transport:</strong></td>
                                <td>₹${request.transport_charges?.toFixed(2) || '0.00'}</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="text-right"><strong>Grand Total:</strong></td>
                                <td>₹${request.total_amount?.toFixed(2) || '0.00'}</td>
                            </tr>
                        </tfoot>
                    </table>
                </div>
            `;
        } else if (request.total_amount > 0) {
            breakdownHtml = `
                <div class="pricing-breakdown">
                    <h3>Pricing Summary</h3>
                    <p><strong>Transport:</strong> ₹${request.transport_charges?.toFixed(2) || '0.00'}</p>
                    <p><strong>Grand Total:</strong> ₹${request.total_amount?.toFixed(2) || '0.00'}</p>
                </div>
            `;
        }

        // Insert breakdown before the generate form
        const notesSection = document.querySelector('.notes-section');
        const existingBreakdown = document.querySelector('.pricing-breakdown');
        if (existingBreakdown) existingBreakdown.remove();
        if (breakdownHtml) {
            notesSection.insertAdjacentHTML('afterend', breakdownHtml);
        }

        // Pre-fill quote items with suggested prices
        const suggestedPrices = {
            '6mm': 120, '8mm': 180, '10mm': 250, '12mm': 320, '14mm': 400,
            '16mm': 480, '18mm': 560, '20mm': 650, '22mm': 750, '24mm': 850,
            '32mm': 1200, '40mm': 1800
        };

        document.getElementById('quoteItemsTable').innerHTML = (request.quote_request_items || []).map(item => {
            const optionName = item.quality_option_name || request.product_name;
            const suggestedPrice = suggestedPrices[optionName] || 100;
            return `
                <tr>
                    <td>
                        <strong>${optionName}</strong><br>
                        <small class="text-muted">${item.quality_option_id ? `Option: ${item.quality_option_id}` : 'Single Product'}</small>
                    </td>
                    <td><span class="badge badge-info">${item.brand_id || request.brand_id || 'N/A'}</span></td>
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
        document.getElementById('paymentTerms').value = `Credit Terms: 30 days\nPayment due within 30 days from invoice date.\nLate payments may incur additional charges.`;

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
                quality_option_id: requestItem.quality_option_id,
                quality_option_name: requestItem.quality_option_name || currentQuoteRequest.product_name,
                quantity: quantity,
                unit: requestItem.unit,
                unit_price: unitPrice,
                total_price: total
            });

            subtotal += total;
        }

        const tax = subtotal * 0.18;
        const grandTotal = subtotal + tax;

        // Prepare quote data for database
        const quoteData = {
            quote_request_id: currentQuoteRequest.id,
            subtotal: subtotal,
            tax_amount: tax,
            total_amount: grandTotal,
            validity_days: parseInt(document.getElementById('validityPeriod').value),
            payment_terms: document.getElementById('paymentTerms').value,
            additional_notes: document.getElementById('additionalNotes').value,
            bank_name: document.getElementById('bankName').value,
            account_number: document.getElementById('accountNumber').value,
            ifsc_code: document.getElementById('ifscCode').value,
            upi_id: document.getElementById('upiId').value,
            quote_items: quoteItems
        };

        // Get admin user ID from users table
        const { data: adminUser } = await supabase.auth.getUser();
        if (!adminUser.user) throw new Error('Admin not authenticated');

        const { data: adminUserData } = await supabase
            .from('users')
            .select('id')
            .eq('email', adminUser.user.email)
            .single();

        if (!adminUserData) throw new Error('Admin user not found in database');

        // Create quote in database
        const { error } = await supabase
            .from('quotes')
            .insert({
                quote_request_id: quoteData.quote_request_id,
                admin_user_id: adminUserData.id, // Use the ID from users table
                status: 'pending',
                subtotal: quoteData.subtotal,
                tax_amount: quoteData.tax_amount,
                total_amount: quoteData.total_amount,
                validity_days: quoteData.validity_days,
                payment_terms: quoteData.payment_terms,
                additional_notes: quoteData.additional_notes,
                bank_name: quoteData.bank_name,
                account_number: quoteData.account_number,
                ifsc_code: quoteData.ifsc_code,
                upi_id: quoteData.upi_id,
            });

        if (error) throw error;

        // Get the created quote ID
        const { data: createdQuote } = await supabase
            .from('quotes')
            .select('id')
            .eq('quote_request_id', quoteData.quote_request_id)
            .single();

        // Insert quote items
        for (const item of quoteItems) {
            await supabase
                .from('quote_items')
                .insert({
                    quote_id: createdQuote.id,
                    quality_option_id: item.quality_option_id,
                    quality_option_name: item.quality_option_name,
                    quantity: item.quantity,
                    unit: item.unit,
                    unit_price: item.unit_price,
                    total_price: item.total_price,
                });
        }

        // Update quote request status
        await supabase
            .from('quote_requests')
            .update({ status: 'quoted' })
            .eq('id', currentQuoteRequest.id);

        // Show success message
        alert(`Quote generated successfully!\n\nQuote ID: ${createdQuote.id}\nTotal Amount: ₹${grandTotal.toFixed(2)}\n\nQuote has been sent to the customer.`);

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
    
    .text-center {
        text-align: center;
    }
    
    .text-danger {
        color: #dc2626 !important;
    }

    .mr-1 {
        margin-right: 4px;
    }

    .badge-info {
        background-color: #e0f2fe;
        color: #0369a1;
        border: 1px solid #bae6fd;
    }

    .items-summary {
        display: flex;
        flex-direction: column;
        gap: 4px;
        align-items: flex-start;
    }
`;
document.head.appendChild(style); 