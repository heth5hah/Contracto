let currentProductId = null;

// Subcategories mapping
const subcategoriesMap = {
    'BATH & FAUCET': ['ALL ASTRAL CP PRODUCT AS PER CATLOGUE'],
    'BUILDING MATERIAL': [
        'CONSTRUCTION CHEMICAL',
        'CENTRING NAILS',
        'M S BINDING WIRE',
        'TMT BAR',
        'MS STEEL',
        'ACC BLOCKS',
        'BLOCK JOINTING MORTAR',
        'G I WIRE',
        'BARBED WIRE',
        'ELECTRIC CABLE',
        'SUMBERSIBLE PUMP',
        'RECRON FIBRE',
        'PVC CHICKEN MESH JALI',
        'MONOBLOC PUMP',
        'DE WATERING PUMP',
        'SUCTION PIPE',
        'CANVAS PIPE',
        'HOSE PIPE',
        'CURING PIPE',
        'GREEN NET',
        'SAFETY NET',
        'SAFETY NET COUPLER',
        'MS PIPE',
        'REBARING CHEMICAL',
        'ANCHOR FASTNER',
        'TIE ROD',
        'TIE ROD NUT',
        'CUBE MOULD',
        'VIBRATOR',
        'RCC COVER',
        'CI COVER',
        'DI COVER',
        'CI PIPE',
        'CI FITTINGS',
        'CENTRING PLY',
        'CENTRING OIL',
        'CUTTING WHEEL',
        'GRINDING WHEEL',
        'BENDING MACHINE',
        'CUTTING MACHINE',
        'GYPSUM',
        'TILE FIXING CHEMICAL',
        'PUTTY',
        'WHITE CEMENT',
        'LEVEL PLAST'
    ],
    'ASIAN PAINTS': ['AS PER CATLOGUE'],
    'PLUMBING': [
        'UPVC PIPE',
        'CPVC PIPE',
        'PVC PIPE',
        'FOAMCORE PIPE',
        'D-REX PIPE',
        'CPVC FIRE PRO PIPE',
        'DI PIPE',
        'DI FITTING',
        'CI PIPE',
        'CI FITTING',
        'SLUICE VALVE',
        'BRASS BALL VALVE',
        'BRASS GATE VALVE',
        'SOLUTION',
        'AGRI PIPE',
        'AGRI FITTING',
        'HDPE PIPE',
        'HDPE FITTING',
        'PIPE PANA',
        'CHAIN PANA',
        'BRASS FOOT VALVE',
        'PVC FOOT VALVE',
        'NOZZLE',
        'BORE JOINTER',
        'SHUDDLE CLIP',
        'HOSE CLIP',
        'BORE CLIP',
        'BORE CLAMP',
        'BORE CAP',
        'BORE ADAPTOR',
        'UPVC FITTING',
        'CPVC FITTING',
        'PVC FITTING',
        'CPVC FIRE PRO FITTING',
        'PARNALI'
    ],
    'TOOLS': [
        'PLY CUTTER',
        'WOOD CUTTER',
        'GRINDER',
        'CHAIN SAW',
        'CUTT OF SAW',
        'MARBLE CUTTER',
        'SCREW FIXING MACHINE',
        'HAMMER MACHINE',
        'BREAKER',
        'GRASS CUTTER'
    ],
    'PUMP': [
        'BOREWELL PUMP',
        'MONOBLOC PUMP',
        'BOOSTER PUMP',
        'FIRE PUMP',
        'OPENWELL PUMPS'
    ],
    'DUSTBINS': []
};

// Unit options for products
const unitOptions = [
    'Millimeter',
    'Metre', 
    'Kg',
    'Feet',
    'Centimetres',
    'Ton',
    'Sq.ft',
    'Litre',
    'Piece',
    'Set',
    'Box',
    'Bundle',
    'Bag'
];

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

// Toggle pricing fields based on pricing type selection
function togglePricingFields() {
    const pricingType = document.getElementById('pricingType').value;
    const fixedPriceFields = document.getElementById('fixedPriceFields');
    const whatsappFields = document.getElementById('whatsappFields');
    const quoteRequestFields = document.getElementById('quoteRequestFields');
    
    // Hide all pricing fields first
    fixedPriceFields.style.display = 'none';
    whatsappFields.style.display = 'none';
    quoteRequestFields.style.display = 'none';
    
    // Show relevant fields based on selection
    switch(pricingType) {
        case 'fixed_price':
            fixedPriceFields.style.display = 'block';
            break;
        case 'whatsapp_request':
            whatsappFields.style.display = 'block';
            break;
        case 'quote_request':
            quoteRequestFields.style.display = 'block';
            break;
    }
}

// Get pricing display text for table
function getPricingDisplayText(product) {
    switch(product.pricing_type) {
        case 'fixed_price':
            if (product.final_price != null) {
                return `₹${product.final_price.toFixed(2)}`;
            } else if (product.mrp != null) {
                return `₹${product.mrp.toFixed(2)}`;
            }
            return 'Price not set';
        case 'whatsapp_request':
            return 'Contact on WhatsApp';
        case 'quote_request':
            return 'Request Quote';
        default:
            return '-';
    }
}

// Get stock status display text
function getStockStatusDisplayText(product) {
    switch(product.stock_status) {
        case 'in_stock':
            return '<span class="status-badge active">In Stock</span>';
        case 'out_of_stock':
            return '<span class="status-badge inactive">Out of Stock</span>';
        default:
            return '<span class="status-badge inactive">Unknown</span>';
    }
}

// Get pricing type display text
function getPricingTypeDisplayText(product) {
    switch(product.pricing_type) {
        case 'fixed_price':
            return 'Fixed Price';
        case 'whatsapp_request':
            return 'WhatsApp Request';
        case 'quote_request':
            return 'Quote Request';
        default:
            return '-';
    }
}

// Get brand names by IDs
async function getBrandNamesByIds(brandIds) {
    if (!brandIds || brandIds.length === 0) return [];
    
    try {
        const supabaseClient = await waitForSupabase();
        const { data: brands, error } = await supabaseClient
            .from('brands')
            .select('id, name')
            .in('id', brandIds);
        
        if (error) throw error;
        return brands.map(brand => brand.name);
    } catch (error) {
        console.error('Error fetching brand names:', error);
        return [];
    }
}

// Load products with proper brand names
async function loadProducts() {
    try {
        const supabaseClient = await waitForSupabase();
        const { data: products, error } = await supabaseClient
            .from('products')
            .select('*, brands(name)')
            .order('created_at', { ascending: false });
        if (error) throw error;
        
        const tableBody = document.getElementById('productsTable');
        tableBody.innerHTML = '';
        
        // Process products and fetch brand names for multiple brands
        for (const product of products) {
            const row = document.createElement('tr');
            
            // Enhanced photo display with debugging
            let photoHtml = '-';
            if (product.photos) {
                if (typeof product.photos === 'string') {
                    // Handle case where photos might be stored as string
                    try {
                        const parsedPhotos = JSON.parse(product.photos);
                        if (Array.isArray(parsedPhotos) && parsedPhotos.length > 0) {
                            photoHtml = `<img src="${parsedPhotos[0]}" alt="${product.product_name}" class="product-photo">`;
                        }
                    } catch (e) {
                        // Single photo as string
                        if (product.photos.includes('http')) {
                            photoHtml = `<img src="${product.photos}" alt="${product.product_name}" class="product-photo">`;
                        }
                    }
                } else if (Array.isArray(product.photos) && product.photos.length > 0) {
                    // Normal array case
                    photoHtml = `<img src="${product.photos[0]}" alt="${product.product_name}" class="product-photo">`;
                }
            }
            
            let qualityOptionsDisplay = '-';
            if (product.quality_options && product.quality_options.length > 0) {
                if (typeof product.quality_options[0] === 'string') {
                    // Old format - just options
                    qualityOptionsDisplay = product.quality_options.join(', ');
                } else {
                    // New format - options with pricing
                    qualityOptionsDisplay = product.quality_options.map(option => {
                        if (option.price) {
                            // Old format with just price
                            return `${option.option} - ₹${option.price.toFixed(2)}`;
                        } else if (option.finalPrice) {
                            // New format with MRP, discount, final price
                            return `${option.option} - ₹${option.finalPrice.toFixed(2)}`;
                        } else {
                            // Fallback
                            return option.option;
                        }
                    }).join(', ');
                }
            }
            
            // Handle brand display - check both old and new format
            let brandsDisplay = '-';
            if (product.brand_ids && Array.isArray(product.brand_ids) && product.brand_ids.length > 0) {
                // New format: multiple brands - fetch actual brand names
                const brandNames = await getBrandNamesByIds(product.brand_ids);
                if (brandNames.length > 0) {
                    brandsDisplay = brandNames.join(', ');
                } else {
                    brandsDisplay = `${product.brand_ids.length} brand(s)`;
                }
            } else if (product.brand_id && product.brands && product.brands.name) {
                // Old format: single brand
                brandsDisplay = product.brands.name;
            } else if (product.brands && product.brands.name) {
                // Fallback for single brand
                brandsDisplay = product.brands.name;
            }
            
            row.innerHTML = `
                <td>${product.product_id || '-'}</td>
                <td>${photoHtml}</td>
                <td>${brandsDisplay}</td>
                <td>${product.category || '-'}</td>
                <td>${product.subcategory || '-'}</td>
                <td>${product.product_name || '-'}</td>
                <td>${product.unit || '-'}</td>
                <td>${getStockStatusDisplayText(product)}</td>
                <td>${getPricingTypeDisplayText(product)}</td>
                <td>${getPricingDisplayText(product)}</td>
                <td>${qualityOptionsDisplay}</td>
                <td>${product.description || '-'}</td>
                <td>${product.hsn_number || '-'}</td>
                <td>${product.gst_percent != null ? product.gst_percent + '%' : '-'}</td>
                <td>
                    <button onclick="editProduct('${product.id}')" class="btn-icon">
                        <i class="ri-edit-line"></i>
                    </button>
                    <button onclick="deleteProduct('${product.id}')" class="btn-icon delete">
                        <i class="ri-delete-bin-line"></i>
                    </button>
                </td>
            `;
            tableBody.appendChild(row);
        }

        // Load brands for selection
        await loadAllBrands();
        setupMultipleBrandSelection();
        
        // Categories are now handled by autocomplete
        // No need to populate dropdown as it's handled by setupCategoryAutocomplete()

        // Load units dropdown
        loadUnitsDropdown();
    } catch (error) {
        console.error('Error loading products:', error);
        alert('Failed to load products. Please try again.');
    }
}

// Open add product modal
async function openAddProductModal() {
    currentProductId = null;
    const modal = document.getElementById('productModal');
    if (!modal) {
        console.error('Product modal not found');
        return;
    }
    
    const form = modal.querySelector('#productForm');
    if (form) {
        form.reset();
    }
    
    // Reset and load brands autocomplete
    await loadBrandsForAutocomplete();
    setupBrandAutocomplete();
    
    // Reset category and subcategory
    const categorySelect = document.getElementById('category');
    const subcategoryInput = document.getElementById('subcategory');
    if (categorySelect) categorySelect.value = '';
    if (subcategoryInput) subcategoryInput.value = '';
    
    // Reset quality options
    loadQualityOptions([]);
    
    // Clear photo preview and file input
    const photoPreview = document.getElementById('photoPreview');
    const photoInput = document.getElementById('productPhotos');
    const photoContainer = document.getElementById('photoUploadContainer');
    if (photoPreview) photoPreview.innerHTML = '';
    if (photoInput) photoInput.value = '';
    if (photoContainer) photoContainer.classList.remove('has-files');
    
    // Reset global uploaded files array
    uploadedFiles = [];
    
    modal.classList.add('show');
}

// Close product modal
function closeProductModal() {
    const modal = document.getElementById('productModal');
    if (modal) {
        modal.classList.remove('show');
        
        // Clear photo preview and file input
        const photoPreview = document.getElementById('photoPreview');
        const photoInput = document.getElementById('productPhotos');
        const photoContainer = document.getElementById('photoUploadContainer');
        if (photoPreview) photoPreview.innerHTML = '';
        if (photoInput) photoInput.value = '';
        if (photoContainer) photoContainer.classList.remove('has-files');
        
        // Reset global uploaded files array
        uploadedFiles = [];
    }
}

// Close quick add brand modal
function closeQuickAddBrandModal() {
    const modal = document.getElementById('quickAddBrandModal');
    if (modal) {
        modal.classList.remove('show');
    }
}

// Close quick add category modal
function closeQuickAddCategoryModal() {
    const modal = document.getElementById('quickAddCategoryModal');
    if (modal) {
        modal.classList.remove('show');
    }
}

// Open quick add brand modal
function openQuickAddBrand() {
    const modal = document.getElementById('quickAddBrandModal');
    if (modal) {
        const form = modal.querySelector('#quickAddBrandForm');
        if (form) form.reset();
        modal.classList.add('show');
    }
}

// Open quick add category modal
function openQuickAddCategory() {
    const modal = document.getElementById('quickAddCategoryModal');
    if (modal) {
        const form = modal.querySelector('#quickAddCategoryForm');
        if (form) form.reset();
        modal.classList.add('show');
    }
}

// Open quick add subcategory modal
function openQuickAddSubcategory() {
    const modal = document.getElementById('quickAddSubcategoryModal');
    if (modal) {
        const form = modal.querySelector('#quickAddSubcategoryForm');
        if (form) form.reset();
        
        // Pre-select the current category if one is selected
        const selectedCategory = document.getElementById('category').value;
        if (selectedCategory) {
            document.getElementById('quickSubcategoryCategory').value = selectedCategory;
        }
        
        modal.classList.add('show');
    }
}

// Close quick add subcategory modal
function closeQuickAddSubcategoryModal() {
    const modal = document.getElementById('quickAddSubcategoryModal');
    if (modal) {
        modal.classList.remove('show');
    }
}

// Open modal for editing an existing product
async function editProduct(productId) {
    try {
        const supabaseClient = await waitForSupabase();
        const { data: product, error } = await supabaseClient
            .from('products')
            .select('*')
            .eq('id', productId)
            .single();
        if (error) throw error;
        
        currentProductId = productId;
        document.getElementById('modalTitle').textContent = 'Edit Product';
        document.getElementById('productId').value = product.product_id || '';
        
        // Load selected brands for editing
        let brandIds = [];
        if (product.brand_ids && Array.isArray(product.brand_ids)) {
            brandIds = product.brand_ids;
        } else if (product.brand_id) {
            brandIds = [product.brand_id];
        }
        await loadAllBrands();
        loadSelectedBrands(brandIds);
        
        document.getElementById('category').value = product.category || '';
        updateSubcategoriesList(product.category);
        document.getElementById('subcategory').value = product.subcategory || '';
        document.getElementById('productName').value = product.product_name || '';
        document.getElementById('productUnit').value = product.unit || '';
        document.getElementById('stockStatus').value = product.stock_status || 'in_stock';
        document.getElementById('pricingType').value = product.pricing_type || '';
        togglePricingFields(); // Show/hide relevant pricing fields
        document.getElementById('productDescription').value = product.description || '';
        document.getElementById('mrp').value = product.mrp != null ? product.mrp : '';
        document.getElementById('hsnNumber').value = product.hsn_number || '';
        document.getElementById('gstPercent').value = product.gst_percent != null ? product.gst_percent : '';
        document.getElementById('discountPercent').value = product.discount_percent != null ? product.discount_percent : '';
        document.getElementById('finalPrice').value = product.final_price != null ? product.final_price : '';
        document.getElementById('whatsappMessage').value = product.whatsapp_message || '';
        document.getElementById('quoteInstructions').value = product.quote_instructions || '';
        
        // Load quality options
        loadQualityOptions(product.quality_options || []);

        // Show existing photos
        const previewContainer = document.getElementById('photoPreview');
        previewContainer.innerHTML = '';
        if (product.photos && product.photos.length > 0) {
            product.photos.forEach((photoUrl, index) => {
                const photoItem = document.createElement('div');
                photoItem.className = 'photo-item';
                photoItem.innerHTML = `
                    <img src="${photoUrl}" alt="Product photo ${index + 1}">
                    <button type="button" class="remove-photo" onclick="removeExistingPhoto(this, '${photoUrl}')">×</button>
                `;
                previewContainer.appendChild(photoItem);
            });
        }

        document.getElementById('productModal').classList.add('show');
    } catch (error) {
        console.error('Error loading product:', error);
        alert('Failed to load product details. Please try again.');
    }
}



// Delete a product
async function deleteProduct(productId) {
    if (!confirm('Are you sure you want to delete this product?')) return;

    try {
        const supabaseClient = await waitForSupabase();
        const { error } = await supabaseClient
            .from('products')
            .delete()
            .eq('id', productId);

        if (error) throw error;

        await loadProducts();
        alert('Product deleted successfully!');
    } catch (error) {
        console.error('Error deleting product:', error);
        alert('Failed to delete product. Please try again.');
    }
} 

// Setup search functionality
function setupSearchListener() {
    const searchInput = document.getElementById('searchProducts');
    let debounceTimer;

    searchInput.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            const searchTerm = e.target.value.toLowerCase();
            filterProducts(searchTerm);
        }, 300);
    });
}

// Setup category autocomplete
function setupCategoryAutocomplete() {
    const categoryInput = document.getElementById('category');
    const categoryDropdown = document.getElementById('categoryDropdown');
    
    if (!categoryInput || !categoryDropdown) return;
    
    const categories = Object.keys(subcategoriesMap);
    let selectedIndex = -1;
    let filteredCategories = [];
    
    categoryInput.addEventListener('input', function() {
        const query = this.value.toLowerCase();
        filteredCategories = categories.filter(category => 
            category.toLowerCase().includes(query)
        );
        
        selectedIndex = -1;
        showCategoryDropdown();
    });
    
    categoryInput.addEventListener('keydown', function(e) {
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            selectedIndex = Math.min(selectedIndex + 1, filteredCategories.length - 1);
            updateCategoryDropdownSelection();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            selectedIndex = Math.max(selectedIndex - 1, -1);
            updateCategoryDropdownSelection();
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (selectedIndex >= 0 && filteredCategories[selectedIndex]) {
                selectCategory(filteredCategories[selectedIndex]);
            }
        } else if (e.key === 'Escape') {
            hideCategoryDropdown();
        }
    });
    
    categoryInput.addEventListener('focus', function() {
        if (this.value) {
            const query = this.value.toLowerCase();
            filteredCategories = categories.filter(category => 
                category.toLowerCase().includes(query)
            );
            showCategoryDropdown();
        }
    });
    
    // Hide dropdown when clicking outside
    document.addEventListener('click', function(e) {
        if (!categoryInput.contains(e.target) && !categoryDropdown.contains(e.target)) {
            hideCategoryDropdown();
        }
    });
    
    function showCategoryDropdown() {
        if (filteredCategories.length > 0) {
            categoryDropdown.innerHTML = '';
            filteredCategories.forEach((category, index) => {
                const item = document.createElement('div');
                item.className = 'autocomplete-item';
                item.textContent = category;
                item.addEventListener('click', () => selectCategory(category));
                categoryDropdown.appendChild(item);
            });
            categoryDropdown.style.display = 'block';
        } else {
            hideCategoryDropdown();
        }
    }
    
    function hideCategoryDropdown() {
        categoryDropdown.style.display = 'none';
        selectedIndex = -1;
    }
    
    function updateCategoryDropdownSelection() {
        const items = categoryDropdown.querySelectorAll('.autocomplete-item');
        items.forEach((item, index) => {
            item.classList.toggle('selected', index === selectedIndex);
        });
    }
    
    function selectCategory(category) {
        categoryInput.value = category;
        hideCategoryDropdown();
        updateSubcategoriesList(category);
    }
}

// Setup subcategory autocomplete
function setupSubcategoryAutocomplete() {
    const subcategoryInput = document.getElementById('subcategory');
    const subcategoryDropdown = document.getElementById('subcategoryDropdown');
    
    if (!subcategoryInput || !subcategoryDropdown) return;
    
    let selectedIndex = -1;
    let filteredSubcategories = [];
    
    subcategoryInput.addEventListener('input', function() {
        const query = this.value.toLowerCase();
        const currentCategory = document.getElementById('category').value;
        const subcategories = subcategoriesMap[currentCategory] || [];
        
        filteredSubcategories = subcategories.filter(subcategory => 
            subcategory.toLowerCase().includes(query)
        );
        
        selectedIndex = -1;
        showSubcategoryDropdown();
    });
    
    subcategoryInput.addEventListener('keydown', function(e) {
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            selectedIndex = Math.min(selectedIndex + 1, filteredSubcategories.length - 1);
            updateSubcategoryDropdownSelection();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            selectedIndex = Math.max(selectedIndex - 1, -1);
            updateSubcategoryDropdownSelection();
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (selectedIndex >= 0 && filteredSubcategories[selectedIndex]) {
                selectSubcategory(filteredSubcategories[selectedIndex]);
            }
        } else if (e.key === 'Escape') {
            hideSubcategoryDropdown();
        }
    });
    
    subcategoryInput.addEventListener('focus', function() {
        if (this.value) {
            const query = this.value.toLowerCase();
            const currentCategory = document.getElementById('category').value;
            const subcategories = subcategoriesMap[currentCategory] || [];
            
            filteredSubcategories = subcategories.filter(subcategory => 
                subcategory.toLowerCase().includes(query)
            );
            showSubcategoryDropdown();
        }
    });
    
    // Hide dropdown when clicking outside
    document.addEventListener('click', function(e) {
        if (!subcategoryInput.contains(e.target) && !subcategoryDropdown.contains(e.target)) {
            hideSubcategoryDropdown();
        }
    });
    
    function showSubcategoryDropdown() {
        if (filteredSubcategories.length > 0) {
            subcategoryDropdown.innerHTML = '';
            filteredSubcategories.forEach((subcategory, index) => {
                const item = document.createElement('div');
                item.className = 'autocomplete-item';
                item.textContent = subcategory;
                item.addEventListener('click', () => selectSubcategory(subcategory));
                subcategoryDropdown.appendChild(item);
            });
            subcategoryDropdown.style.display = 'block';
        } else {
            hideSubcategoryDropdown();
        }
    }
    
    function hideSubcategoryDropdown() {
        subcategoryDropdown.style.display = 'none';
        selectedIndex = -1;
    }
    
    function updateSubcategoryDropdownSelection() {
        const items = subcategoryDropdown.querySelectorAll('.autocomplete-item');
        items.forEach((item, index) => {
            item.classList.toggle('selected', index === selectedIndex);
        });
    }
    
    function selectSubcategory(subcategory) {
        subcategoryInput.value = subcategory;
        hideSubcategoryDropdown();
    }
}

// Setup category change listener (legacy)
function setupCategoryListener() {
    const categoryInput = document.getElementById('category');
    categoryInput.addEventListener('change', (e) => {
        const category = e.target.value;
        updateSubcategoriesList(category);
    });
}

// Update subcategories dropdown based on selected category
function updateSubcategoriesList(category) {
    const subcategoryInput = document.getElementById('subcategory');
    if (subcategoryInput) {
        subcategoryInput.value = ''; // Clear current selection
    }
}

// Filter products based on search term
function filterProducts(searchTerm) {
    const rows = document.querySelectorAll('#productsTable tr');
    rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(searchTerm) ? '' : 'none';
    });
}

// Fetch brands for autocomplete
async function loadBrandsForAutocomplete(selectedId = null) {
    const supabaseClient = await waitForSupabase();
    const { data: brands, error } = await supabaseClient
        .from('brands')
        .select('id, name')
        .order('name');
    
    if (error) {
        console.error('Error loading brands:', error);
        return [];
    }
    
    // Store brands globally for autocomplete
    window.availableBrands = brands;
    
    // Set selected brand if editing
    if (selectedId) {
        const selectedBrand = brands.find(brand => brand.id === selectedId);
        if (selectedBrand) {
            document.getElementById('brandId').value = selectedBrand.name;
            document.getElementById('brandIdValue').value = selectedBrand.id;
        }
    }
    
    return brands;
}

// Setup brand autocomplete
function setupBrandAutocomplete() {
    const brandInput = document.getElementById('brandId');
    const brandDropdown = document.getElementById('brandDropdown');
    const brandValueInput = document.getElementById('brandIdValue');
    
    if (!brandInput || !brandDropdown) return;
    
    let selectedIndex = -1;
    let filteredBrands = [];
    
    brandInput.addEventListener('input', function() {
        const query = this.value.toLowerCase();
        filteredBrands = window.availableBrands.filter(brand => 
            brand.name.toLowerCase().includes(query)
        );
        
        selectedIndex = -1;
        showBrandDropdown();
    });
    
    brandInput.addEventListener('keydown', function(e) {
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            selectedIndex = Math.min(selectedIndex + 1, filteredBrands.length - 1);
            updateBrandDropdownSelection();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            selectedIndex = Math.max(selectedIndex - 1, -1);
            updateBrandDropdownSelection();
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (selectedIndex >= 0 && filteredBrands[selectedIndex]) {
                selectBrand(filteredBrands[selectedIndex]);
            }
        } else if (e.key === 'Escape') {
            hideBrandDropdown();
        }
    });
    
    brandInput.addEventListener('focus', function() {
        if (this.value) {
            const query = this.value.toLowerCase();
            filteredBrands = window.availableBrands.filter(brand => 
                brand.name.toLowerCase().includes(query)
            );
            showBrandDropdown();
        }
    });
    
    // Hide dropdown when clicking outside
    document.addEventListener('click', function(e) {
        if (!brandInput.contains(e.target) && !brandDropdown.contains(e.target)) {
            hideBrandDropdown();
        }
    });
    
    function showBrandDropdown() {
        if (filteredBrands.length > 0) {
            brandDropdown.innerHTML = '';
            filteredBrands.forEach((brand, index) => {
                const item = document.createElement('div');
                item.className = 'autocomplete-item';
                item.textContent = brand.name;
                item.addEventListener('click', () => selectBrand(brand));
                brandDropdown.appendChild(item);
            });
            brandDropdown.style.display = 'block';
        } else {
            hideBrandDropdown();
        }
    }
    
    function hideBrandDropdown() {
        brandDropdown.style.display = 'none';
        selectedIndex = -1;
    }
    
    function updateBrandDropdownSelection() {
        const items = brandDropdown.querySelectorAll('.autocomplete-item');
        items.forEach((item, index) => {
            item.classList.toggle('selected', index === selectedIndex);
        });
    }
    
    function selectBrand(brand) {
        brandInput.value = brand.name;
        brandValueInput.value = brand.id;
        hideBrandDropdown();
    }
}

// Load units dropdown
function loadUnitsDropdown() {
    const unitSelect = document.getElementById('productUnit');
    if (!unitSelect) return;
    
    unitSelect.innerHTML = '<option value="">Select Unit</option>';
    unitOptions.forEach(unit => {
        const option = document.createElement('option');
        option.value = unit;
        option.textContent = unit;
        unitSelect.appendChild(option);
    });
}

// Add quality option
function addQualityOption() {
    const container = document.getElementById('qualityOptionsContainer');
    
    if (!container) {
        console.error('qualityOptionsContainer not found');
        return;
    }
    
    const optionDiv = document.createElement('div');
    optionDiv.className = 'quality-option-item';
    optionDiv.innerHTML = `
        <div>
            <div class="quality-price-label">Quality Option</div>
            <input type="text" placeholder="e.g., 5 kg, 10 kg" class="quality-option-input">
        </div>
        <div>
            <div class="quality-price-label">MRP (₹)</div>
            <input type="number" placeholder="0.00" step="0.01" class="quality-mrp-input" onchange="updateQualityFinalPrice(this)">
        </div>
        <div>
            <div class="quality-price-label">Discount (%)</div>
            <input type="number" placeholder="0" min="0" max="100" step="0.01" class="quality-discount-input" onchange="updateQualityFinalPrice(this)">
        </div>
        <div>
            <div class="quality-price-label">Final Price (₹)</div>
            <input type="number" placeholder="0.00" step="0.01" class="quality-final-input" onchange="updateQualityDiscount(this)">
        </div>
        <button type="button" onclick="removeQualityOption(this)" class="btn-remove">
            <i class="ri-close-line"></i>
        </button>
    `;
    
    container.appendChild(optionDiv);
}

// Remove quality option
function removeQualityOption(button) {
    const optionItem = button.parentElement;
    optionItem.remove();
}

// Update quality option final price based on MRP and discount
function updateQualityFinalPrice(input) {
    const item = input.closest('.quality-option-item');
    const mrpInput = item.querySelector('.quality-mrp-input');
    const discountInput = item.querySelector('.quality-discount-input');
    const finalInput = item.querySelector('.quality-final-input');
    
    const mrp = parseFloat(mrpInput.value) || 0;
    const discount = parseFloat(discountInput.value) || 0;
    const finalPrice = mrp - (mrp * (discount / 100));
    
    finalInput.value = finalPrice.toFixed(2);
}

// Update quality option discount based on MRP and final price
function updateQualityDiscount(input) {
    const item = input.closest('.quality-option-item');
    const mrpInput = item.querySelector('.quality-mrp-input');
    const discountInput = item.querySelector('.quality-discount-input');
    const finalInput = item.querySelector('.quality-final-input');
    
    const mrp = parseFloat(mrpInput.value) || 0;
    const finalPrice = parseFloat(finalInput.value) || 0;
    
    if (mrp > 0 && finalPrice > 0) {
        const discount = ((mrp - finalPrice) / mrp) * 100;
        discountInput.value = Math.max(0, Math.min(100, discount)).toFixed(2);
    }
}

// Get quality options from form
function getQualityOptions() {
    const container = document.getElementById('qualityOptionsContainer');
    const options = [];
    
    container.querySelectorAll('.quality-option-item').forEach(item => {
        const optionInput = item.querySelector('.quality-option-input');
        const mrpInput = item.querySelector('.quality-mrp-input');
        const discountInput = item.querySelector('.quality-discount-input');
        const finalInput = item.querySelector('.quality-final-input');
        
        const optionValue = optionInput.value.trim();
        const mrpValue = parseFloat(mrpInput.value) || 0;
        const discountValue = parseFloat(discountInput.value) || 0;
        const finalValue = parseFloat(finalInput.value) || 0;
        
        if (optionValue) {
            options.push({
                option: optionValue,
                mrp: mrpValue,
                discount: discountValue,
                finalPrice: finalValue
            });
        }
    });
    
    return options;
}

// Load quality options into form
function loadQualityOptions(options) {
    const container = document.getElementById('qualityOptionsContainer');
    
    if (!container) {
        console.error('qualityOptionsContainer not found in loadQualityOptions');
        return;
    }
    
    container.innerHTML = '';
    
    if (options.length === 0) {
        // Add one empty option
        addQualityOption();
        return;
    }
    
    options.forEach(option => {
        const optionDiv = document.createElement('div');
        optionDiv.className = 'quality-option-item';
        
        // Handle both old format (string) and new format (object)
        const optionValue = typeof option === 'string' ? option : option.option || '';
        const mrpValue = typeof option === 'object' ? (option.mrp || 0) : 0;
        const discountValue = typeof option === 'object' ? (option.discount || 0) : 0;
        const finalValue = typeof option === 'object' ? (option.finalPrice || 0) : 0;
        
        optionDiv.innerHTML = `
            <div>
                <div class="quality-price-label">Quality Option</div>
                <input type="text" value="${optionValue}" class="quality-option-input">
            </div>
            <div>
                <div class="quality-price-label">MRP (₹)</div>
                <input type="number" value="${mrpValue}" step="0.01" class="quality-mrp-input" onchange="updateQualityFinalPrice(this)">
            </div>
            <div>
                <div class="quality-price-label">Discount (%)</div>
                <input type="number" value="${discountValue}" min="0" max="100" step="0.01" class="quality-discount-input" onchange="updateQualityFinalPrice(this)">
            </div>
            <div>
                <div class="quality-price-label">Final Price (₹)</div>
                <input type="number" value="${finalValue}" step="0.01" class="quality-final-input" onchange="updateQualityDiscount(this)">
            </div>
            <button type="button" onclick="removeQualityOption(this)" class="btn-remove">
                <i class="ri-close-line"></i>
            </button>
        `;
        container.appendChild(optionDiv);
    });
}

// Get existing photos from preview (for edit mode)
function getExistingPhotosFromPreview() {
    const previewContainer = document.getElementById('photoPreview');
    const existingPhotos = [];
    
    // Get URLs from existing photo items (not new uploads)
    previewContainer.querySelectorAll('.photo-item img').forEach(img => {
        const src = img.src;
        // Only include if it's a Supabase URL (existing photo) and not a data URL
        if (src.includes('supabase.co') && !src.startsWith('data:')) {
            existingPhotos.push(src);
        }
    });
    
    return existingPhotos;
}

// Debug function to check photo data
async function debugProductPhotos(productId) {
    const supabaseClient = await waitForSupabase();
    const { data: product, error } = await supabaseClient
        .from('products')
        .select('photos')
        .eq('id', productId)
        .single();
    
    console.log('Product photos from DB:', product?.photos);
    console.log('Photos type:', typeof product?.photos);
    console.log('Photos array check:', Array.isArray(product?.photos));
}

// Add required field indicators to the form
document.addEventListener('DOMContentLoaded', async () => {
    try {
        // Ensure all modals are hidden on page load
        document.querySelectorAll('.modal').forEach(modal => {
            modal.classList.remove('show');
        });

        await waitForSupabase();
        await loadProducts();
        await loadBrandsForAutocomplete();
        setupSearchListener();
        setupCategoryListener();
        setupCategoryAutocomplete();
        setupSubcategoryAutocomplete();
        setupBrandAutocomplete();
        
        // Add required field indicators
        const requiredFields = [
            'productId',
            'productName',
            'brandId',
            'category',
            'mrp'
        ];
        
        requiredFields.forEach(fieldId => {
            const label = document.querySelector(`label[for="${fieldId}"]`);
            if (label) {
                label.classList.add('required');
            }
        });

        // Setup form submission handlers
        const productForm = document.getElementById('productForm');
        if (productForm) {
            productForm.addEventListener('submit', handleProductSubmit);
        }

        const quickAddBrandForm = document.getElementById('quickAddBrandForm');
        if (quickAddBrandForm) {
            quickAddBrandForm.addEventListener('submit', handleQuickAddBrand);
        }

        const quickAddCategoryForm = document.getElementById('quickAddCategoryForm');
        if (quickAddCategoryForm) {
            quickAddCategoryForm.addEventListener('submit', handleQuickAddCategory);
        }

        const quickAddSubcategoryForm = document.getElementById('quickAddSubcategoryForm');
        if (quickAddSubcategoryForm) {
            quickAddSubcategoryForm.addEventListener('submit', handleQuickAddSubcategory);
        }

        // Close modals when clicking outside
        window.addEventListener('click', (e) => {
            document.querySelectorAll('.modal').forEach(modal => {
                if (e.target === modal) {
                    modal.classList.remove('show');
                }
            });
        });

        // Initialize drag & drop for photo upload
        initializeDragAndDrop();

        // Add photo upload handler
        const photoInput = document.getElementById('productPhotos');
        if (photoInput) {
            photoInput.addEventListener('change', handlePhotoUpload);
        }

        // Add pricing change handlers
        const mrpInput = document.getElementById('mrp');
        if (mrpInput) {
            mrpInput.addEventListener('change', updatePricingFromMRP);
        }

        const discountInput = document.getElementById('discountPercent');
        if (discountInput) {
            discountInput.addEventListener('change', updatePricingFromDiscount);
        }

        const finalPriceInput = document.getElementById('finalPrice');
        if (finalPriceInput) {
            finalPriceInput.addEventListener('change', updatePricingFromFinalPrice);
        }
    } catch (error) {
        console.error('Error initializing:', error);
        alert('Failed to initialize. Please refresh the page.');
    }
});

// Handle quick add brand submission
async function handleQuickAddBrand(e) {
    e.preventDefault();
    try {
        const supabaseClient = await waitForSupabase();
        const brandData = {
            name: document.getElementById('quickBrandName').value,
            description: document.getElementById('quickBrandDescription').value,
            is_active: true
        };
        
        const { data, error } = await supabaseClient
            .from('brands')
            .insert([brandData])
            .select()
            .single();
            
        if (error) throw error;
        
        closeQuickAddBrandModal();
        await loadBrandsForAutocomplete(data.id);
        setupBrandAutocomplete();
        alert('Brand added successfully!');
    } catch (error) {
        console.error('Error adding brand:', error);
        alert('Failed to add brand. Please try again.');
    }
}

// Handle quick add category submission
async function handleQuickAddCategory(e) {
    e.preventDefault();
    const categoryName = document.getElementById('quickCategoryName').value;
    const categoryInput = document.getElementById('category');
    
    // Add new category to the mapping
    if (!subcategoriesMap[categoryName]) {
        subcategoriesMap[categoryName] = [];
    }
    
    // Set the new category
    categoryInput.value = categoryName;
    updateSubcategoriesList(categoryName);
    
    closeQuickAddCategoryModal();
    alert('Category added successfully!');
}

// Handle quick add subcategory submission
async function handleQuickAddSubcategory(e) {
    e.preventDefault();
    const parentCategory = document.getElementById('quickSubcategoryCategory').value;
    const subcategoryName = document.getElementById('quickSubcategoryName').value;
    
    if (!parentCategory) {
        alert('Please select a parent category');
        return;
    }
    
    // Add subcategory to the mapping
    if (!subcategoriesMap[parentCategory]) {
        subcategoriesMap[parentCategory] = [];
    }
    
    if (!subcategoriesMap[parentCategory].includes(subcategoryName)) {
        subcategoriesMap[parentCategory].push(subcategoryName);
    }
    
    // If this category is currently selected, update the subcategory input
    const currentCategory = document.getElementById('category').value;
    if (currentCategory === parentCategory) {
        updateSubcategoriesList(parentCategory);
        // Select the newly added subcategory
        document.getElementById('subcategory').value = subcategoryName;
    }
    
    closeQuickAddSubcategoryModal();
    alert('Subcategory added successfully!');
}

// Handle product form submission
async function handleProductSubmit(e) {
    e.preventDefault();
    
    // Reset any previous error states
    document.querySelectorAll('.form-group').forEach(group => {
        group.classList.remove('has-error');
        const errorMsg = group.querySelector('.error-message');
        if (errorMsg) errorMsg.remove();
    });

    try {
        const supabaseClient = await waitForSupabase();
        const selectedBrandIds = getSelectedBrandIds();
        console.log('Selected brand IDs:', selectedBrandIds);
        const productData = {
            product_id: document.getElementById('productId').value,
            product_name: document.getElementById('productName').value,
            brand_ids: selectedBrandIds.length > 0 ? selectedBrandIds : null, // Array of brand IDs or null
            category: document.getElementById('category').value,
            subcategory: document.getElementById('subcategory').value,
            unit: document.getElementById('productUnit').value,
            stock_status: document.getElementById('stockStatus').value,
            pricing_type: document.getElementById('pricingType').value,
            quality_options: getQualityOptions(),
            description: document.getElementById('productDescription').value,
            mrp: parseFloat(document.getElementById('mrp').value) || null,
            hsn_number: document.getElementById('hsnNumber').value,
            gst_percent: parseFloat(document.getElementById('gstPercent').value) || null,
            discount_percent: parseFloat(document.getElementById('discountPercent').value) || 0,
            final_price: parseFloat(document.getElementById('finalPrice').value) || null,
            whatsapp_message: document.getElementById('whatsappMessage') ? document.getElementById('whatsappMessage').value : null,
            quote_instructions: document.getElementById('quoteInstructions') ? document.getElementById('quoteInstructions').value : null
        };
        console.log('Product data being sent:', productData);

        // Check if product ID already exists (only for new products)
        let existingProduct = null;
        if (!currentProductId) {
            const { data: checkResult, error: checkError } = await supabaseClient
            .from('products')
            .select('product_id')
            .eq('product_id', productData.product_id)
                .maybeSingle();
            
            // Ignore 406 errors which can happen with certain queries
            if (!checkError || checkError.code !== 'PGRST116') {
                existingProduct = checkResult;
            }
        }

        if (existingProduct && !currentProductId) {
            // Show error for duplicate product ID
            const productIdGroup = document.getElementById('productId').closest('.form-group');
            productIdGroup.classList.add('has-error');
            const errorMsg = document.createElement('div');
            errorMsg.className = 'error-message';
            errorMsg.textContent = 'This Product ID already exists. Please use a different one.';
            productIdGroup.appendChild(errorMsg);
            return;
        }

        let result;
        if (currentProductId) {
            result = await supabaseClient
                .from('products')
                .update(productData)
                .eq('id', currentProductId)
                .select()
                .single();
        } else {
            result = await supabaseClient
                .from('products')
                .insert([productData])
                .select()
                .single();
        }

        if (result.error) {
            if (result.error.code === '23505') {
                // Handle duplicate key error
                const productIdGroup = document.getElementById('productId').closest('.form-group');
                productIdGroup.classList.add('has-error');
                const errorMsg = document.createElement('div');
                errorMsg.className = 'error-message';
                errorMsg.textContent = 'This Product ID already exists. Please use a different one.';
                productIdGroup.appendChild(errorMsg);
            } else {
                throw result.error;
            }
            return;
        }
        
        // Upload photos and update product with photo URLs
        const photoUrls = await uploadPhotos(result.data.id);
        
        // Get existing photos if this is an update
        let finalPhotoUrls = photoUrls;
        if (currentProductId) {
            // For updates, get existing photos from preview
            const existingPhotos = getExistingPhotosFromPreview();
            finalPhotoUrls = [...existingPhotos, ...photoUrls];
        }
        
        // Update product with photos (even if empty array)
        if (finalPhotoUrls.length >= 0) {
            const { error: photoUpdateError } = await supabaseClient
                .from('products')
                .update({ photos: finalPhotoUrls })
                .eq('id', result.data.id);

            if (photoUpdateError) throw photoUpdateError;
            
            // Debug: Log the saved photos
            console.log('Photos saved:', finalPhotoUrls);
            debugProductPhotos(result.data.id);
        }
        
        closeProductModal();
        await loadProducts();
        alert(`Product ${currentProductId ? 'updated' : 'added'} successfully!`);
    } catch (error) {
        console.error('Error saving product:', error);
        if (error.code === '23505') {
            // Handle duplicate key error
            const productIdGroup = document.getElementById('productId').closest('.form-group');
            productIdGroup.classList.add('has-error');
            const errorMsg = document.createElement('div');
            errorMsg.className = 'error-message';
            errorMsg.textContent = 'This Product ID already exists. Please use a different one.';
            productIdGroup.appendChild(errorMsg);
        } else {
            alert('Failed to save product. Please try again.');
        }
    }
}

// Add this helper function to show field errors
function showFieldError(fieldId, message) {
    const group = document.getElementById(fieldId).closest('.form-group');
    group.classList.add('has-error');
    const errorMsg = document.createElement('div');
    errorMsg.className = 'error-message';
    errorMsg.textContent = message;
    group.appendChild(errorMsg);
} 

// Handle photo uploads and preview
// Global variable to store all uploaded files
let uploadedFiles = [];

function handlePhotoUpload(event) {
    const files = event.target.files;
    const photoContainer = document.getElementById('photoUploadContainer');
    const photoPreview = document.getElementById('photoPreview');
    
    if (files.length > 0) {
        photoContainer.classList.add('has-files');
        
        // Add new files to the global array
        Array.from(files).forEach(file => {
            uploadedFiles.push(file);
        });
        
        // Update preview with all files
        updatePreview(uploadedFiles);
        
        // Clear the file input for next selection
        event.target.value = '';
    } else {
        photoContainer.classList.remove('has-files');
        if (photoPreview.children.length === 0) {
            photoPreview.innerHTML = '';
        }
    }
}

// Remove photo from preview (for new uploads)
function removePhoto(button) {
    const photoItem = button.parentElement;
    const photoIndex = Array.from(photoItem.parentElement.children).indexOf(photoItem);
    photoItem.remove();
    
    // Remove the file from the global array
    if (photoIndex >= 0 && photoIndex < uploadedFiles.length) {
        uploadedFiles.splice(photoIndex, 1);
    }
    
    // Clear file input if all photos are removed
    const previewContainer = document.getElementById('photoPreview');
    if (previewContainer.children.length === 0) {
        const fileInput = document.getElementById('productPhotos');
        fileInput.value = '';
        const photoContainer = document.getElementById('photoUploadContainer');
        if (photoContainer) {
            photoContainer.classList.remove('has-files');
        }
        uploadedFiles = []; // Clear the global array
    }
}

// Remove existing photo from preview (for edit mode)
function removeExistingPhoto(button, photoUrl) {
    const photoItem = button.parentElement;
    photoItem.remove();
    
    // Clear file input if all photos are removed
    const previewContainer = document.getElementById('photoPreview');
    if (previewContainer.children.length === 0) {
        const fileInput = document.getElementById('productPhotos');
        fileInput.value = '';
        const photoContainer = document.getElementById('photoUploadContainer');
        if (photoContainer) {
            photoContainer.classList.remove('has-files');
        }
    }
}

// Update pricing from MRP
function updatePricingFromMRP() {
    const mrp = parseFloat(document.getElementById('mrp').value) || 0;
    const discountPercent = parseFloat(document.getElementById('discountPercent').value) || 0;
    const finalPrice = mrp - (mrp * (discountPercent / 100));
    document.getElementById('finalPrice').value = finalPrice.toFixed(2);
}

// Update pricing from discount
function updatePricingFromDiscount() {
    const mrp = parseFloat(document.getElementById('mrp').value) || 0;
    const discountPercent = parseFloat(document.getElementById('discountPercent').value) || 0;
    const finalPrice = mrp - (mrp * (discountPercent / 100));
    document.getElementById('finalPrice').value = finalPrice.toFixed(2);
}

// Update pricing from final price
function updatePricingFromFinalPrice() {
    const mrp = parseFloat(document.getElementById('mrp').value) || 0;
    const finalPrice = parseFloat(document.getElementById('finalPrice').value) || 0;
    
    if (mrp > 0 && finalPrice > 0) {
        const discountPercent = ((mrp - finalPrice) / mrp) * 100;
        document.getElementById('discountPercent').value = Math.max(0, Math.min(100, discountPercent)).toFixed(2);
    }
}

// Legacy function for backward compatibility
function updateFinalPrice() {
    updatePricingFromMRP();
}

// Upload photos to Supabase storage
async function uploadPhotos(productId) {
    const files = uploadedFiles; // Use the global array instead of file input
    const photoUrls = [];

    if (files.length === 0) return photoUrls;

    const supabaseClient = await waitForSupabase();
    
    for (let file of files) {
        // Check file size (20MB limit)
        if (file.size > 20 * 1024 * 1024) {
            console.error(`File "${file.name}" is too large. Maximum size is 20MB.`);
            continue;
        }
        
        // Check file type
        if (!file.type.match('image.*')) {
            console.error(`File "${file.name}" is not a valid image file.`);
            continue;
        }
        
        const fileExt = file.name.split('.').pop();
        const fileName = `${productId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
        
        try {
            const { data, error } = await supabaseClient.storage
                .from('product-photos')
                .upload(`products/${fileName}`, file, {
                    cacheControl: '3600',
                    upsert: false
                });

            if (error) {
                console.error('Error uploading photo:', error);
                continue;
            }

            const { data: { publicUrl } } = supabaseClient.storage
                .from('product-photos')
                .getPublicUrl(`products/${fileName}`);
            
            photoUrls.push(publicUrl);
        } catch (error) {
            console.error('Error uploading photo:', error);
            continue;
        }
    }

    return photoUrls;
} 

// Initialize drag and drop functionality
function initializeDragAndDrop() {
    const photoInput = document.getElementById('productPhotos');
    const photoContainer = document.getElementById('photoUploadContainer');
    const photoPreview = document.getElementById('photoPreview');
    
    if (!photoContainer || !photoInput) return;

    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        photoContainer.addEventListener(eventName, preventDefaults, false);
        document.body.addEventListener(eventName, preventDefaults, false);
    });

    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
        photoContainer.addEventListener(eventName, highlight, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        photoContainer.addEventListener(eventName, unhighlight, false);
    });

    // Handle dropped files
    photoContainer.addEventListener('drop', handleDrop, false);

    // Make container clickable
    photoContainer.addEventListener('click', () => photoInput.click());

    // File input change is handled by handlePhotoUpload in DOMContentLoaded

    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    function highlight(e) {
        photoContainer.classList.add('drag-over');
    }

    function unhighlight(e) {
        photoContainer.classList.remove('drag-over');
    }

    function handleDrop(e) {
        const dt = e.dataTransfer;
        const files = dt.files;
        
        // Create new FileList and assign to input
        const dataTransfer = new DataTransfer();
        Array.from(files).forEach(file => {
            dataTransfer.items.add(file);
        });
        photoInput.files = dataTransfer.files;
        
        // Trigger the change event to use handlePhotoUpload
        const event = new Event('change', { bubbles: true });
        photoInput.dispatchEvent(event);
    }
} 

// Update photo preview (shared function for both drag-drop and file input)
function updatePreview(files) {
    const photoPreview = document.getElementById('photoPreview');
    if (!photoPreview) return;
    
    // Don't clear existing previews - append new ones
    const existingCount = photoPreview.children.length;
    
    Array.from(files).forEach((file, index) => {
        // Check file size (20MB limit)
        if (file.size > 20 * 1024 * 1024) {
            alert(`File "${file.name}" is too large. Maximum size is 20MB.`);
            return;
        }
        
        // Check file type
        if (!file.type.match('image.*')) {
            alert(`File "${file.name}" is not a valid image file.`);
            return;
        }
        
        const reader = new FileReader();
        reader.onload = function(e) {
            const photoItem = document.createElement('div');
            photoItem.className = 'photo-item';
            photoItem.innerHTML = `
                <img src="${e.target.result}" alt="Product photo ${existingCount + index + 1}">
                <button type="button" class="remove-photo" onclick="removePhoto(this)">×</button>
            `;
            photoPreview.appendChild(photoItem);
        };
        reader.readAsDataURL(file);
    });
}

// Global variables for multiple brand selection
let selectedBrands = [];
let allBrands = [];

// Setup multiple brand selection
function setupMultipleBrandSelection() {
    const brandSearch = document.getElementById('brandSearch');
    const brandDropdown = document.getElementById('brandDropdown');
    const selectedBrandsContainer = document.getElementById('selectedBrands');
    
    if (!brandSearch || !brandDropdown || !selectedBrandsContainer) return;
    
    let filteredBrands = [];
    let selectedIndex = -1;
    
    // Load all brands
    loadAllBrands();
    
    // Search functionality
    brandSearch.addEventListener('input', (e) => {
        const searchTerm = e.target.value.toLowerCase();
        filterBrands(searchTerm);
    });
    
    // Show dropdown on focus
    brandSearch.addEventListener('focus', () => {
        showBrandDropdown();
    });
    
    // Handle keyboard navigation
    brandSearch.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            selectedIndex = Math.min(selectedIndex + 1, filteredBrands.length - 1);
            updateBrandDropdownSelection();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            selectedIndex = Math.max(selectedIndex - 1, -1);
            updateBrandDropdownSelection();
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (selectedIndex >= 0 && selectedIndex < filteredBrands.length) {
                selectBrand(filteredBrands[selectedIndex]);
            }
        } else if (e.key === 'Escape') {
            hideBrandDropdown();
        }
    });
    
    // Hide dropdown when clicking outside
    document.addEventListener('click', (e) => {
        if (!brandSearch.contains(e.target) && !brandDropdown.contains(e.target)) {
            hideBrandDropdown();
        }
    });
    
    function filterBrands(searchTerm) {
        filteredBrands = allBrands.filter(brand => 
            brand.name.toLowerCase().includes(searchTerm) &&
            !selectedBrands.some(selected => selected.id === brand.id)
        );
        selectedIndex = -1;
        updateBrandDropdown();
    }
    
    function updateBrandDropdown() {
        brandDropdown.innerHTML = '';
        
        if (filteredBrands.length === 0) {
            brandDropdown.innerHTML = '<div class="brand-option">No brands found</div>';
            return;
        }
        
        filteredBrands.forEach((brand, index) => {
            const option = document.createElement('div');
            option.className = 'brand-option';
            option.innerHTML = `
                ${brand.logo_url ? `<img src="${brand.logo_url}" alt="${brand.name}" class="brand-logo">` : ''}
                <div class="brand-name">${brand.name}</div>
                <div class="brand-description">${brand.description || ''}</div>
            `;
            option.addEventListener('click', () => selectBrand(brand));
            brandDropdown.appendChild(option);
        });
    }
    
    function updateBrandDropdownSelection() {
        const options = brandDropdown.querySelectorAll('.brand-option');
        options.forEach((option, index) => {
            option.classList.toggle('selected', index === selectedIndex);
        });
    }
    
    function selectBrand(brand) {
        if (!selectedBrands.some(selected => selected.id === brand.id)) {
            selectedBrands.push(brand);
            updateSelectedBrandsDisplay();
        }
        brandSearch.value = '';
        hideBrandDropdown();
        filterBrands('');
    }
    
    function updateSelectedBrandsDisplay() {
        selectedBrandsContainer.innerHTML = '';
        
        selectedBrands.forEach(brand => {
            const brandTag = document.createElement('div');
            brandTag.className = 'brand-tag';
            brandTag.innerHTML = `
                ${brand.logo_url ? `<img src="${brand.logo_url}" alt="${brand.name}" class="brand-logo">` : ''}
                <span>${brand.name}</span>
                <button type="button" class="remove-brand" onclick="removeBrand('${brand.id}')">×</button>
            `;
            selectedBrandsContainer.appendChild(brandTag);
        });
    }
    
    function showBrandDropdown() {
        brandDropdown.style.display = 'block';
        filterBrands(brandSearch.value.toLowerCase());
    }
    
    function hideBrandDropdown() {
        brandDropdown.style.display = 'none';
    }
    
    // Make functions globally available
    window.removeBrand = function(brandId) {
        selectedBrands = selectedBrands.filter(brand => brand.id !== brandId);
        updateSelectedBrandsDisplay();
        filterBrands(brandSearch.value.toLowerCase());
    };
}

// Load all brands for selection
async function loadAllBrands() {
    try {
        const supabaseClient = await waitForSupabase();
        const { data: brands, error } = await supabaseClient
            .from('brands')
            .select('*')
            .eq('is_active', true)
            .order('name');
        
        if (error) throw error;
        
        allBrands = brands || [];
    } catch (error) {
        console.error('Error loading brands:', error);
        allBrands = [];
    }
}

// Get selected brand IDs for form submission
function getSelectedBrandIds() {
    return selectedBrands.map(brand => brand.id);
}

// Load selected brands for editing
function loadSelectedBrands(brandIds) {
    selectedBrands = allBrands.filter(brand => brandIds.includes(brand.id));
    updateSelectedBrandsDisplay();
}

// Update selected brands display
function updateSelectedBrandsDisplay() {
    const selectedBrandsContainer = document.getElementById('selectedBrands');
    if (!selectedBrandsContainer) return;
    
    selectedBrandsContainer.innerHTML = '';
    
    selectedBrands.forEach(brand => {
        const brandTag = document.createElement('div');
        brandTag.className = 'brand-tag';
        brandTag.innerHTML = `
            ${brand.logo_url ? `<img src="${brand.logo_url}" alt="${brand.name}" class="brand-logo">` : ''}
            <span>${brand.name}</span>
            <button type="button" class="remove-brand" onclick="removeBrand('${brand.id}')">×</button>
        `;
        selectedBrandsContainer.appendChild(brandTag);
    });
}