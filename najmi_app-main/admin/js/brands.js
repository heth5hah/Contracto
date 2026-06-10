let currentBrandId = null;

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

// Load all brands from Supabase
async function loadBrands() {
    try {
        const supabaseClient = await waitForSupabase();
        const { data: brands, error } = await supabaseClient
            .from('brands')
            .select('*')
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        const tableBody = document.getElementById('brandsTable');
        tableBody.innerHTML = '';
        
        brands.forEach(brand => {
            const row = document.createElement('tr');
            const catalogLink = brand.catalog_pdf_url 
                ? `<a href="${brand.catalog_pdf_url}" target="_blank" class="catalog-link">
                     <i class="ri-file-pdf-line"></i> View Catalog
                   </a>` 
                : '-';
            
            row.innerHTML = `
                <td>
                    <div class="brand-info">
                        ${brand.logo_url ? `<img src="${brand.logo_url}" alt="${brand.name}" class="brand-logo">` : ''}
                        <span>${brand.name}</span>
                    </div>
                </td>
                <td>${brand.description || '-'}</td>
                <td>${catalogLink}</td>
                <td>
                    <span class="status-badge ${brand.is_active ? 'active' : 'inactive'}">
                        ${brand.is_active ? 'Active' : 'Inactive'}
                    </span>
                </td>
                <td>${new Date(brand.created_at).toLocaleDateString()}</td>
                <td>
                    <button onclick="editBrand('${brand.id}')" class="btn-icon">
                        <i class="ri-edit-line"></i>
                    </button>
                    <button onclick="deleteBrand('${brand.id}')" class="btn-icon delete">
                        <i class="ri-delete-bin-line"></i>
                    </button>
                </td>
            `;
            tableBody.appendChild(row);
        });
    } catch (error) {
        console.error('Error loading brands:', error);
        alert('Failed to load brands. Please try again.');
    }
}

// Open add brand modal
function openAddBrandModal() {
    currentBrandId = null;
    const modal = document.getElementById('brandModal');
    if (!modal) {
        console.error('Brand modal not found');
        return;
    }
    
    const form = modal.querySelector('#brandForm');
    if (form) {
        form.reset();
    }
    
    // Reset file previews
    const catalogPreview = document.getElementById('catalogPreview');
    if (catalogPreview) {
        catalogPreview.innerHTML = '';
    }
    
    const logoPreview = document.getElementById('logoPreview');
    if (logoPreview) {
        logoPreview.innerHTML = '';
    }
    
    document.getElementById('modalTitle').textContent = 'Add Brand';
    modal.classList.add('show');
}

// Close brand modal
function closeBrandModal() {
    const modal = document.getElementById('brandModal');
    if (modal) {
        modal.classList.remove('show');
    }
}

// Open modal for editing an existing brand
async function editBrand(brandId) {
    try {
        const supabaseClient = await waitForSupabase();
        const { data: brand, error } = await supabaseClient
            .from('brands')
            .select('*')
            .eq('id', brandId)
            .single();
        
        if (error) throw error;
        
        currentBrandId = brandId;
        const modalTitle = document.getElementById('modalTitle');
        const brandName = document.getElementById('brandName');
        const brandDescription = document.getElementById('brandDescription');
        const isActive = document.getElementById('isActive');
        
        if (modalTitle) modalTitle.textContent = 'Edit Brand';
        if (brandName) brandName.value = brand.name || '';
        if (brandDescription) brandDescription.value = brand.description || '';
        if (isActive) isActive.value = brand.is_active.toString();
        
        // Show existing logo if available
        const logoPreview = document.getElementById('logoPreview');
        if (logoPreview) {
            logoPreview.innerHTML = '';
            if (brand.logo_url) {
                const logoItem = document.createElement('div');
                logoItem.className = 'logo-item';
                logoItem.innerHTML = `
                    <div class="logo-info">
                        <img src="${brand.logo_url}" alt="Brand Logo" class="preview-logo">
                        <span>Current Logo</span>
                    </div>
                    <button type="button" class="remove-logo" onclick="removeLogo(this)">×</button>
                `;
                logoPreview.appendChild(logoItem);
            }
        }

        // Show existing catalog if available
        const catalogPreview = document.getElementById('catalogPreview');
        if (catalogPreview) {
            catalogPreview.innerHTML = '';
            if (brand.catalog_pdf_url) {
                const catalogItem = document.createElement('div');
                catalogItem.className = 'catalog-item';
                catalogItem.innerHTML = `
                    <div class="catalog-info">
                        <i class="ri-file-pdf-line"></i>
                        <span>Current Catalog</span>
                        <a href="${brand.catalog_pdf_url}" target="_blank" class="view-link">View</a>
                    </div>
                    <button type="button" class="remove-catalog" onclick="removeCatalog(this)">×</button>
                `;
                catalogPreview.appendChild(catalogItem);
            }
        }

        const brandModal = document.getElementById('brandModal');
        if (brandModal) {
            brandModal.classList.add('show');
        }
    } catch (error) {
        console.error('Error loading brand:', error);
        alert('Failed to load brand details. Please try again.');
    }
}

// Delete a brand
async function deleteBrand(brandId) {
    if (!confirm('Are you sure you want to delete this brand? This action cannot be undone.')) return;

    try {
        const supabaseClient = await waitForSupabase();
        const { error } = await supabaseClient
            .from('brands')
            .delete()
            .eq('id', brandId);

        if (error) throw error;

        await loadBrands();
        alert('Brand deleted successfully!');
    } catch (error) {
        console.error('Error deleting brand:', error);
        alert('Failed to delete brand. Please try again.');
    }
}

// Setup search functionality
function setupSearchListener() {
    const searchInput = document.getElementById('searchBrands');
    let debounceTimer;

    searchInput.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            const searchTerm = e.target.value.toLowerCase();
            filterBrands(searchTerm);
        }, 300);
    });
}

// Filter brands based on search term
function filterBrands(searchTerm) {
    const rows = document.querySelectorAll('#brandsTable tr');
    rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(searchTerm) ? '' : 'none';
    });
}

// Handle brand form submission
async function handleBrandSubmit(e) {
    e.preventDefault();
    
    try {
        const supabaseClient = await waitForSupabase();
        const brandData = {
            name: document.getElementById('brandName').value,
            description: document.getElementById('brandDescription').value,
            is_active: document.getElementById('isActive').value === 'true'
        };

        let result;
        if (currentBrandId) {
            result = await supabaseClient
                .from('brands')
                .update(brandData)
                .eq('id', currentBrandId)
                .select()
                .single();
        } else {
            result = await supabaseClient
                .from('brands')
                .insert([brandData])
                .select()
                .single();
        }

        if (result.error) throw result.error;
        
        // Upload logo if provided
        const logoUrl = await uploadBrandLogo(result.data.id);
        
        // Upload catalog PDF if provided
        const catalogUrl = await uploadCatalogPDF(result.data.id);
        
        // Update with uploaded files URLs
        const updateData = {};
        if (logoUrl) updateData.logo_url = logoUrl;
        if (catalogUrl) updateData.catalog_pdf_url = catalogUrl;
        
        if (Object.keys(updateData).length > 0) {
            const { error: updateError } = await supabaseClient
                .from('brands')
                .update(updateData)
                .eq('id', result.data.id);

            if (updateError) throw updateError;
        }
        
        closeBrandModal();
        await loadBrands();
        alert(`Brand ${currentBrandId ? 'updated' : 'added'} successfully!`);
    } catch (error) {
        console.error('Error saving brand:', error);
        alert('Failed to save brand. Please try again.');
    }
}

// Handle catalog PDF upload
function handleCatalogUpload(event) {
    const file = event.target.files[0];
    const catalogPreview = document.getElementById('catalogPreview');
    catalogPreview.innerHTML = '';

    if (file) {
        if (file.type !== 'application/pdf') {
            alert('Please select a PDF file only.');
            event.target.value = '';
            return;
        }

        if (file.size > 20 * 1024 * 1024) { // 20MB limit
            alert('File size must be less than 20MB.');
            event.target.value = '';
            return;
        }

        const catalogItem = document.createElement('div');
        catalogItem.className = 'catalog-item';
        catalogItem.innerHTML = `
            <div class="catalog-info">
                <i class="ri-file-pdf-line"></i>
                <span>${file.name}</span>
                <small>${(file.size / 1024 / 1024).toFixed(2)} MB</small>
            </div>
            <button type="button" class="remove-catalog" onclick="removeCatalog(this)">×</button>
        `;
        catalogPreview.appendChild(catalogItem);
    }
}

// Remove catalog from preview
function removeCatalog(button) {
    const catalogItem = button.parentElement;
    catalogItem.remove();
    
    // Clear file input
    document.getElementById('catalogPdf').value = '';
}

// Upload catalog PDF to Supabase storage
async function uploadCatalogPDF(brandId) {
    const fileInput = document.getElementById('catalogPdf');
    const file = fileInput.files[0];

    if (!file) return null;

    const supabaseClient = await waitForSupabase();
    
    const fileExt = file.name.split('.').pop();
    const fileName = `${brandId}_catalog_${Date.now()}.${fileExt}`;
    
    const { data, error } = await supabaseClient.storage
        .from('brand-catalogs')
        .upload(`catalogs/${fileName}`, file);

    if (error) {
        console.error('Error uploading catalog:', error);
        return null;
    }

    const { data: { publicUrl } } = supabaseClient.storage
        .from('brand-catalogs')
        .getPublicUrl(`catalogs/${fileName}`);
    
    return publicUrl;
}

// Handle logo upload
function handleLogoUpload(event) {
    const file = event.target.files[0];
    const logoPreview = document.getElementById('logoPreview');
    logoPreview.innerHTML = '';

    if (file) {
        if (!file.type.match('image.*')) {
            alert('Please select an image file only.');
            event.target.value = '';
            return;
        }

        if (file.size > 5 * 1024 * 1024) { // 5MB limit
            alert('File size must be less than 5MB.');
            event.target.value = '';
            return;
        }

        // Preview the image
        const reader = new FileReader();
        reader.onload = function(e) {
            const logoItem = document.createElement('div');
            logoItem.className = 'logo-item';
            logoItem.innerHTML = `
                <div class="logo-info">
                    <img src="${e.target.result}" alt="Logo Preview" class="preview-logo">
                    <span>${file.name}</span>
                    <small>${(file.size / 1024 / 1024).toFixed(2)} MB</small>
                </div>
                <button type="button" class="remove-logo" onclick="removeLogo(this)">×</button>
            `;
            logoPreview.appendChild(logoItem);
        };
        reader.readAsDataURL(file);
    }
}

// Remove logo from preview
function removeLogo(button) {
    const logoItem = button.parentElement;
    logoItem.remove();
    
    // Clear file input
    document.getElementById('brandLogo').value = '';
}

// Upload brand logo to Supabase storage
async function uploadBrandLogo(brandId) {
    const fileInput = document.getElementById('brandLogo');
    const file = fileInput.files[0];

    if (!file) return null;

    try {
        const supabaseClient = await waitForSupabase();
        const fileExt = file.name.split('.').pop();
        const fileName = `${brandId}_logo_${Date.now()}.${fileExt}`;
        
        const { data, error } = await supabaseClient.storage
            .from('brand-logos')
            .upload(`logos/${fileName}`, file);

        if (error) throw error;

        const { data: { publicUrl } } = supabaseClient.storage
            .from('brand-logos')
            .getPublicUrl(`logos/${fileName}`);
        
        return publicUrl;
    } catch (error) {
        console.error('Error uploading logo:', error);
        alert('Failed to upload logo. Please try again.');
        return null;
    }
}

// Initialize drag and drop functionality for logo upload
function initializeLogoDragAndDrop() {
    const logoInput = document.getElementById('brandLogo');
    const logoContainer = document.getElementById('logoUploadContainer');
    
    if (!logoContainer || !logoInput) return;

    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        logoContainer.addEventListener(eventName, preventDefaults, false);
    });

    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
        logoContainer.addEventListener(eventName, highlight, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        logoContainer.addEventListener(eventName, unhighlight, false);
    });

    // Handle dropped files
    logoContainer.addEventListener('drop', handleDrop, false);

    // Make container clickable
    logoContainer.addEventListener('click', () => logoInput.click());

    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    function highlight(e) {
        logoContainer.classList.add('drag-over');
    }

    function unhighlight(e) {
        logoContainer.classList.remove('drag-over');
    }

    function handleDrop(e) {
        const dt = e.dataTransfer;
        const files = dt.files;
        
        if (files.length > 0) {
            logoInput.files = files;
            handleLogoUpload({ target: logoInput });
        }
    }
}

// Initialize drag and drop functionality for catalog upload
function initializeCatalogDragAndDrop() {
    const catalogInput = document.getElementById('catalogPdf');
    const catalogContainer = document.getElementById('catalogUploadContainer');
    
    if (!catalogContainer || !catalogInput) return;

    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        catalogContainer.addEventListener(eventName, preventDefaults, false);
    });

    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
        catalogContainer.addEventListener(eventName, highlight, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        catalogContainer.addEventListener(eventName, unhighlight, false);
    });

    // Handle dropped files
    catalogContainer.addEventListener('drop', handleDrop, false);

    // Make container clickable
    catalogContainer.addEventListener('click', () => catalogInput.click());

    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    function highlight(e) {
        catalogContainer.classList.add('drag-over');
    }

    function unhighlight(e) {
        catalogContainer.classList.remove('drag-over');
    }

    function handleDrop(e) {
        const dt = e.dataTransfer;
        const files = dt.files;
        
        if (files.length > 0) {
            catalogInput.files = files;
            handleCatalogUpload({ target: catalogInput });
        }
    }
}

// Initialize the page
document.addEventListener('DOMContentLoaded', async () => {
    try {
        // Ensure all modals are hidden on page load
        document.querySelectorAll('.modal').forEach(modal => {
            modal.classList.remove('show');
        });

        await waitForSupabase();
        await loadBrands();
        setupSearchListener();
        
        // Setup form submission handler
        const brandForm = document.getElementById('brandForm');
        if (brandForm) {
            brandForm.addEventListener('submit', handleBrandSubmit);
        }

        // Setup file upload handlers
        const catalogInput = document.getElementById('catalogPdf');
        if (catalogInput) {
            catalogInput.addEventListener('change', handleCatalogUpload);
        }

        const logoInput = document.getElementById('brandLogo');
        if (logoInput) {
            logoInput.addEventListener('change', handleLogoUpload);
        }

        // Initialize drag & drop for uploads
        initializeCatalogDragAndDrop();
        initializeLogoDragAndDrop();

        // Close modals when clicking outside
        window.addEventListener('click', (e) => {
            document.querySelectorAll('.modal').forEach(modal => {
                if (e.target === modal) {
                    modal.classList.remove('show');
                }
            });
        });
    } catch (error) {
        console.error('Error initializing brands page:', error);
        alert('Failed to initialize. Please refresh the page.');
    }
}); 