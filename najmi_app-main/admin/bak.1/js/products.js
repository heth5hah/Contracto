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

// Load all products from Supabase
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
        products.forEach(product => {
            const row = document.createElement('tr');
            const photoHtml = product.photos && product.photos.length > 0 
                ? `<img src="${product.photos[0]}" alt="${product.product_name}" class="product-photo">` 
                : '-';
            
            row.innerHTML = `
                <td>${product.product_id || '-'}</td>
                <td>${photoHtml}</td>
                <td>${product.brands ? product.brands.name : '-'}</td>
                <td>${product.category || '-'}</td>
                <td>${product.subcategory || '-'}</td>
                <td>${product.product_name || '-'}</td>
                <td>${product.description || '-'}</td>
                <td>₹${product.mrp != null ? product.mrp.toFixed(2) : '-'}</td>
                <td>${product.discount_percent != null ? product.discount_percent.toFixed(1) + '%' : '0%'}</td>
                <td>₹${product.final_price != null ? product.final_price.toFixed(2) : (product.mrp != null ? product.mrp.toFixed(2) : '-')}</td>
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
        });

        // Load brands for dropdown
        await loadBrandsDropdown();
        
        // Load categories
        const categorySelect = document.getElementById('category');
        if (categorySelect) {
            categorySelect.innerHTML = '<option value="">Select Category</option>';
            Object.keys(subcategoriesMap).forEach(category => {
                const option = document.createElement('option');
                option.value = category;
                option.textContent = category;
                categorySelect.appendChild(option);
            });
        }
    } catch (error) {
        console.error('Error loading products:', error);
        alert('Failed to load products. Please try again.');
    }
}

// Open add product modal
function openAddProductModal() {
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
    
    // Reset and load brands dropdown
    loadBrandsDropdown();
    
    // Reset category and subcategory
    const categorySelect = document.getElementById('category');
    const subcategoryInput = document.getElementById('subcategory');
    if (categorySelect) categorySelect.value = '';
    if (subcategoryInput) subcategoryInput.value = '';
    
    modal.classList.add('show');
}

// Close product modal
function closeProductModal() {
    const modal = document.getElementById('productModal');
    if (modal) {
        modal.classList.remove('show');
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
        await loadBrandsDropdown(product.brand_id);
        document.getElementById('category').value = product.category || '';
        updateSubcategoriesList(product.category);
        document.getElementById('subcategory').value = product.subcategory || '';
        document.getElementById('productName').value = product.product_name || '';
        document.getElementById('productDescription').value = product.description || '';
        document.getElementById('mrp').value = product.mrp != null ? product.mrp : '';
        document.getElementById('hsnNumber').value = product.hsn_number || '';
        document.getElementById('gstPercent').value = product.gst_percent != null ? product.gst_percent : '';
        document.getElementById('discountPercent').value = product.discount_percent != null ? product.discount_percent : '';
        document.getElementById('finalPrice').value = product.final_price != null ? product.final_price : '';

        // Show existing photos
        const previewContainer = document.getElementById('photoPreview');
        previewContainer.innerHTML = '';
        if (product.photos && product.photos.length > 0) {
            product.photos.forEach((photoUrl, index) => {
                const photoItem = document.createElement('div');
                photoItem.className = 'photo-item';
                photoItem.innerHTML = `
                    <img src="${photoUrl}" alt="Product photo ${index + 1}">
                    <button type="button" class="remove-photo" onclick="removePhoto(this)">×</button>
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

// Setup category change listener
function setupCategoryListener() {
    const categorySelect = document.getElementById('category');
    categorySelect.addEventListener('change', (e) => {
        const category = e.target.value;
        updateSubcategoriesList(category);
    });
}

// Update subcategories dropdown based on selected category
function updateSubcategoriesList(category) {
    const subcategorySelect = document.getElementById('subcategory');
    subcategorySelect.innerHTML = '<option value="">Select Subcategory</option>';
    
    const subcategories = subcategoriesMap[category] || [];
    subcategories.forEach(subcategory => {
        const option = document.createElement('option');
        option.value = subcategory;
        option.textContent = subcategory;
        subcategorySelect.appendChild(option);
    });
}

// Filter products based on search term
function filterProducts(searchTerm) {
    const rows = document.querySelectorAll('#productsTable tr');
    rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(searchTerm) ? '' : 'none';
    });
}

// Fetch brands for dropdown
async function loadBrandsDropdown(selectedId = null) {
    const brandSelect = document.getElementById('brandId');
    brandSelect.innerHTML = '<option value="">Select Brand</option>';
    const supabaseClient = await waitForSupabase();
    const { data: brands, error } = await supabaseClient
        .from('brands')
        .select('id, name')
        .order('name');
    if (error) {
        console.error('Error loading brands:', error);
        brandSelect.innerHTML = '<option value="">Error loading brands</option>';
        return;
    }
    brands.forEach(brand => {
        const option = document.createElement('option');
        option.value = brand.id;
        option.textContent = brand.name;
        if (selectedId && brand.id === selectedId) option.selected = true;
        brandSelect.appendChild(option);
    });
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
        setupSearchListener();
        setupCategoryListener();
        
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

        // Add MRP change handler
        const mrpInput = document.getElementById('mrp');
        if (mrpInput) {
            mrpInput.addEventListener('change', updateFinalPrice);
        }

        // Add discount change handler
        const discountInput = document.getElementById('discountPercent');
        if (discountInput) {
            discountInput.addEventListener('change', updateFinalPrice);
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
        await loadBrandsDropdown(data.id);
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
    const categorySelect = document.getElementById('category');
    
    // Add new option to select
    const option = document.createElement('option');
    option.value = categoryName;
    option.textContent = categoryName;
    categorySelect.appendChild(option);
    
    // Select the new category
    categorySelect.value = categoryName;
    
    // Initialize empty subcategories for the new category
    subcategoriesMap[categoryName] = [];
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
    
    // If this category is currently selected, update the subcategory dropdown
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
        const productData = {
            product_id: document.getElementById('productId').value,
            product_name: document.getElementById('productName').value,
            brand_id: document.getElementById('brandId').value,
            category: document.getElementById('category').value,
            subcategory: document.getElementById('subcategory').value,
            description: document.getElementById('productDescription').value,
            mrp: parseFloat(document.getElementById('mrp').value) || null,
            hsn_number: document.getElementById('hsnNumber').value,
            gst_percent: parseFloat(document.getElementById('gstPercent').value) || null,
            discount_percent: parseFloat(document.getElementById('discountPercent').value) || 0,
            final_price: parseFloat(document.getElementById('finalPrice').value) || null
        };

        // Check if product ID already exists
        const { data: existingProduct } = await supabaseClient
            .from('products')
            .select('product_id')
            .eq('product_id', productData.product_id)
            .single();

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
        if (photoUrls.length > 0) {
            const { error: photoUpdateError } = await supabaseClient
                .from('products')
                .update({ photos: photoUrls })
                .eq('id', result.data.id);

            if (photoUpdateError) throw photoUpdateError;
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
function handlePhotoUpload(event) {
    const files = event.target.files;
    const previewContainer = document.getElementById('photoPreview');
    previewContainer.innerHTML = '';

    Array.from(files).forEach((file, index) => {
        const reader = new FileReader();
        reader.onload = function(e) {
            const photoItem = document.createElement('div');
            photoItem.className = 'photo-item';
            photoItem.innerHTML = `
                <img src="${e.target.result}" alt="Product photo ${index + 1}">
                <button type="button" class="remove-photo" onclick="removePhoto(this)">×</button>
            `;
            previewContainer.appendChild(photoItem);
        };
        reader.readAsDataURL(file);
    });
}

// Remove photo from preview
function removePhoto(button) {
    const photoItem = button.parentElement;
    photoItem.remove();
    
    // Clear file input if all photos are removed
    const previewContainer = document.getElementById('photoPreview');
    if (previewContainer.children.length === 0) {
        document.getElementById('productPhotos').value = '';
    }
}

// Update final price based on MRP and discount
function updateFinalPrice() {
    const mrp = parseFloat(document.getElementById('mrp').value) || 0;
    const discountPercent = parseFloat(document.getElementById('discountPercent').value) || 0;
    const finalPrice = mrp - (mrp * (discountPercent / 100));
    document.getElementById('finalPrice').value = finalPrice.toFixed(2);
}

// Upload photos to Supabase storage
async function uploadPhotos(productId) {
    const fileInput = document.getElementById('productPhotos');
    const files = fileInput.files;
    const photoUrls = [];

    if (files.length === 0) return photoUrls;

    const supabaseClient = await waitForSupabase();
    
    for (let file of files) {
        const fileExt = file.name.split('.').pop();
        const fileName = `${productId}_${Date.now()}.${fileExt}`;
        const { data, error } = await supabaseClient.storage
            .from('product-photos')
            .upload(`products/${fileName}`, file);

        if (error) {
            console.error('Error uploading photo:', error);
            continue;
        }

        const { data: { publicUrl } } = supabaseClient.storage
            .from('product-photos')
            .getPublicUrl(`products/${fileName}`);
        
        photoUrls.push(publicUrl);
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

    // Handle file input change
    photoInput.addEventListener('change', handleFiles);

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
        photoInput.files = files;
        handleFiles();
    }

    function handleFiles() {
        const files = photoInput.files;
        if (files.length > 0) {
            photoContainer.classList.add('has-files');
            updatePreview(files);
        } else {
            photoContainer.classList.remove('has-files');
            photoPreview.innerHTML = '';
        }
    }

    function updatePreview(files) {
        photoPreview.innerHTML = '';
        
        Array.from(files).forEach(file => {
            if (file.type.match('image.*')) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    const img = document.createElement('img');
                    img.src = e.target.result;
                    photoPreview.appendChild(img);
                };
                reader.readAsDataURL(file);
            }
        });
    }
} 