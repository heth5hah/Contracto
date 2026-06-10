// Categories Management
class CategoriesManager {
    constructor() {
        this.categories = [];
        this.init();
    }

    async init() {
        await this.loadCategories();
        this.setupEventListeners();
        this.renderCategories();
    }

    setupEventListeners() {
        // Add category form
        const addCategoryForm = document.getElementById('addCategoryForm');
        if (addCategoryForm) {
            addCategoryForm.addEventListener('submit', (e) => this.handleAddCategory(e));
        }

        // Edit category form
        const editCategoryForm = document.getElementById('editCategoryForm');
        if (editCategoryForm) {
            editCategoryForm.addEventListener('submit', (e) => this.handleEditCategory(e));
        }

        // Search functionality
        const searchInput = document.getElementById('categorySearch');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => this.filterCategories(e.target.value));
        }

        // Add category button
        const addCategoryBtn = document.getElementById('addCategoryBtn');
        if (addCategoryBtn) {
            addCategoryBtn.addEventListener('click', () => this.showAddCategoryModal());
        }
    }

    async loadCategories() {
        try {
            // Get categories from the existing subcategoriesMap in products.js
            // Since categories are currently stored in JavaScript, we'll create them from the map
            const categories = [
                { 
                    id: 1, 
                    name: 'BATH & FAUCET', 
                    description: 'Bathroom and faucet products', 
                    subcategories: ['ALL ASTRAL CP PRODUCT AS PER CATLOGUE'],
                    is_active: true, 
                    created_at: new Date().toISOString() 
                },
                { 
                    id: 2, 
                    name: 'BUILDING MATERIAL', 
                    description: 'Construction and building materials', 
                    subcategories: [
                        'CONSTRUCTION CHEMICAL', 'CENTRING NAILS', 'M S BINDING WIRE', 'TMT BAR',
                        'MS STEEL', 'ACC BLOCKS', 'BLOCK JOINTING MORTAR', 'G I WIRE',
                        'BARBED WIRE', 'ELECTRIC CABLE', 'SUMBERSIBLE PUMP', 'RECRON FIBRE',
                        'PVC CHICKEN MESH JALI', 'MONOBLOC PUMP', 'DE WATERING PUMP',
                        'SUCTION PIPE', 'CANVAS PIPE', 'HOSE PIPE', 'CURING PIPE',
                        'GREEN NET', 'SAFETY NET', 'SAFETY NET COUPLER', 'MS PIPE',
                        'REBARING CHEMICAL', 'ANCHOR FASTNER', 'TIE ROD', 'TIE ROD NUT',
                        'CUBE MOULD', 'VIBRATOR', 'RCC COVER', 'CI COVER', 'DI COVER',
                        'CI PIPE', 'CI FITTINGS', 'CENTRING PLY', 'CENTRING OIL',
                        'CUTTING WHEEL', 'GRINDING WHEEL', 'BENDING MACHINE',
                        'CUTTING MACHINE', 'GYPSUM', 'TILE FIXING CHEMICAL',
                        'PUTTY', 'WHITE CEMENT', 'LEVEL PLAST'
                    ],
                    is_active: true, 
                    created_at: new Date().toISOString() 
                },
                { 
                    id: 3, 
                    name: 'ASIAN PAINTS', 
                    description: 'Asian Paints products', 
                    subcategories: ['AS PER CATLOGUE'],
                    is_active: true, 
                    created_at: new Date().toISOString() 
                },
                { 
                    id: 4, 
                    name: 'PLUMBING', 
                    description: 'Plumbing supplies and equipment', 
                    subcategories: [
                        'UPVC PIPE', 'CPVC PIPE', 'PVC PIPE', 'FOAMCORE PIPE',
                        'D-REX PIPE', 'CPVC FIRE PRO PIPE', 'DI PIPE', 'DI FITTING',
                        'CI PIPE', 'CI FITTING', 'SLUICE VALVE', 'BRASS BALL VALVE',
                        'BRASS GATE VALVE', 'SOLUTION', 'AGRI PIPE', 'AGRI FITTING',
                        'HDPE PIPE', 'HDPE FITTING', 'PIPE PANA', 'CHAIN PANA',
                        'BRASS FOOT VALVE', 'PVC FOOT VALVE', 'NOZZLE',
                        'BORE JOINTER', 'SHUDDLE CLIP', 'HOSE CLIP', 'BORE CLIP',
                        'BORE CLAMP', 'BORE CAP', 'BORE ADAPTOR', 'UPVC FITTING',
                        'CPVC FITTING', 'PVC FITTING', 'CPVC FIRE PRO FITTING', 'PARNALI'
                    ],
                    is_active: true, 
                    created_at: new Date().toISOString() 
                },
                { 
                    id: 5, 
                    name: 'TOOLS', 
                    description: 'Tools and equipment', 
                    subcategories: [
                        'PLY CUTTER', 'WOOD CUTTER', 'GRINDER', 'CHAIN SAW',
                        'CUTT OF SAW', 'MARBLE CUTTER', 'SCREW FIXING MACHINE',
                        'HAMMER MACHINE', 'BREAKER'
                    ],
                    is_active: true, 
                    created_at: new Date().toISOString() 
                },
                { 
                    id: 6, 
                    name: 'PUMP', 
                    description: 'Pump systems and equipment', 
                    subcategories: [],
                    is_active: true, 
                    created_at: new Date().toISOString() 
                },
                { 
                    id: 7, 
                    name: 'DUSTBINS', 
                    description: 'Dustbins and waste management', 
                    subcategories: [],
                    is_active: true, 
                    created_at: new Date().toISOString() 
                }
            ];

            this.categories = categories;

        } catch (error) {
            console.error('Error loading categories:', error);
            this.showNotification('Error loading categories', 'error');
        }
    }

    async handleAddCategory(e) {
        e.preventDefault();
        
        const formData = new FormData(e.target);
        const subcategoriesText = formData.get('subcategories') || '';
        const subcategories = subcategoriesText.split('\n').filter(sub => sub.trim() !== '');
        
        const categoryData = {
            name: formData.get('name'),
            description: formData.get('description'),
            subcategories: subcategories,
            is_active: formData.get('is_active') === 'true'
        };

        try {
            // For now, we'll just add to the local array since there's no database table
            const newCategory = {
                id: Date.now(), // Simple ID generation
                ...categoryData,
                created_at: new Date().toISOString(),
                product_count: 0
            };

            this.categories.push(newCategory);
            this.renderCategories();
            this.hideAddCategoryModal();
            this.showNotification('Category added successfully', 'success');
            e.target.reset();

        } catch (error) {
            console.error('Error adding category:', error);
            this.showNotification('Error adding category', 'error');
        }
    }

    async updateCategory(id, updates) {
        try {
            const index = this.categories.findIndex(cat => cat.id === id);
            if (index !== -1) {
                this.categories[index] = {...this.categories[index], ...updates};
                this.renderCategories();
            }

            this.showNotification('Category updated successfully', 'success');

        } catch (error) {
            console.error('Error updating category:', error);
            this.showNotification('Error updating category', 'error');
        }
    }

    async deleteCategory(id) {
        if (!confirm('Are you sure you want to delete this category?')) return;

        try {
            this.categories = this.categories.filter(cat => cat.id !== id);
            this.renderCategories();
            this.showNotification('Category deleted successfully', 'success');

        } catch (error) {
            console.error('Error deleting category:', error);
            this.showNotification('Error deleting category', 'error');
        }
    }

    filterCategories(searchTerm) {
        const filtered = this.categories.filter(category =>
            category.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
            (category.description && category.description.toLowerCase().includes(searchTerm.toLowerCase()))
        );
        this.renderCategories(filtered);
    }

    renderCategories(categoriesToRender = this.categories) {
        const tableBody = document.getElementById('categoriesTable');
        if (!tableBody) return;

        if (categoriesToRender.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="7" class="empty-state">
                        <div class="empty-state">
                            <i class="ri-layout-grid-line"></i>
                            <h3>No categories found</h3>
                            <p>Add your first category to get started</p>
                        </div>
                    </td>
                </tr>
            `;
            return;
        }

        tableBody.innerHTML = categoriesToRender.map(category => `
            <tr>
                <td>
                    <div class="category-info">
                        <span class="category-name">${category.name}</span>
                    </div>
                </td>
                <td>${category.description || '-'}</td>
                <td>
                    ${category.subcategories && category.subcategories.length > 0 
                        ? category.subcategories.slice(0, 3).join(', ') + 
                          (category.subcategories.length > 3 ? ` (+${category.subcategories.length - 3} more)` : '')
                        : 'No subcategories'
                    }
                </td>
                <td>
                    <span class="status-badge ${category.is_active ? 'active' : 'inactive'}">
                        ${category.is_active ? 'Active' : 'Inactive'}
                    </span>
                </td>
                <td>${category.product_count || 0}</td>
                <td>${new Date(category.created_at).toLocaleDateString()}</td>
                <td>
                    <button onclick="categoriesManager.editCategory(${category.id})" class="btn-icon">
                        <i class="ri-edit-line"></i>
                    </button>
                    <button onclick="categoriesManager.deleteCategory(${category.id})" class="btn-icon delete">
                        <i class="ri-delete-bin-line"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    }

    showAddCategoryModal() {
        const modal = document.getElementById('addCategoryModal');
        if (modal) {
            modal.classList.add('show');
        }
    }

    hideAddCategoryModal() {
        const modal = document.getElementById('addCategoryModal');
        if (modal) {
            modal.classList.remove('show');
        }
    }

    editCategory(id) {
        const category = this.categories.find(cat => cat.id === id);
        if (!category) return;

        // Populate edit form
        const editCategoryId = document.getElementById('editCategoryId');
        const editCategoryName = document.getElementById('editCategoryName');
        const editCategoryDescription = document.getElementById('editCategoryDescription');
        const editCategorySubcategories = document.getElementById('editCategorySubcategories');
        const editCategoryActive = document.getElementById('editCategoryActive');
        
        if (editCategoryId) editCategoryId.value = category.id;
        if (editCategoryName) editCategoryName.value = category.name;
        if (editCategoryDescription) editCategoryDescription.value = category.description || '';
        if (editCategorySubcategories) editCategorySubcategories.value = category.subcategories ? category.subcategories.join('\n') : '';
        if (editCategoryActive) editCategoryActive.value = category.is_active ? 'true' : 'false';

        // Show edit modal
        const modal = document.getElementById('editCategoryModal');
        if (modal) {
            modal.classList.add('show');
        }
    }

    async handleEditCategory(e) {
        e.preventDefault();
        
        const formData = new FormData(e.target);
        const id = parseInt(formData.get('id'));
        const subcategoriesText = formData.get('subcategories') || '';
        const subcategories = subcategoriesText.split('\n').filter(sub => sub.trim() !== '');
        
        const updates = {
            name: formData.get('name'),
            description: formData.get('description'),
            subcategories: subcategories,
            is_active: formData.get('is_active') === 'true'
        };

        await this.updateCategory(id, updates);
        this.hideEditCategoryModal();
    }

    hideEditCategoryModal() {
        const modal = document.getElementById('editCategoryModal');
        if (modal) {
            modal.classList.remove('show');
        }
    }

    showNotification(message, type = 'info') {
        // Simple notification implementation
        console.log(`${type.toUpperCase()}: ${message}`);
        // You can implement a proper notification system here
    }
}

// Initialize categories manager when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.categoriesManager = new CategoriesManager();
}); 