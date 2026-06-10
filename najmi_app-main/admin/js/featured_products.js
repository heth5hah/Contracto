// Featured Products Management
class FeaturedProductsManager {
    constructor() {
        this.supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        this.currentEditId = null;
        this.init();
    }

    async init() {
        this.loadFeaturedProducts();
        this.loadProducts();
        this.setupEventListeners();
    }

    setupEventListeners() {
        const addBtn = document.getElementById('addFeaturedProductBtn');
        const modal = document.getElementById('featuredProductModal');
        const closeBtn = document.querySelector('.close');
        const form = document.getElementById('featuredProductForm');

        addBtn.addEventListener('click', () => this.openModal());
        closeBtn.addEventListener('click', () => this.closeModal());
        
        window.addEventListener('click', (e) => {
            if (e.target === modal) this.closeModal();
        });

        form.addEventListener('submit', (e) => this.handleSubmit(e));
    }

    async loadFeaturedProducts() {
        try {
            const { data, error } = await this.supabase
                .from('featured_products')
                .select(`
                    *,
                    products (
                        id,
                        product_name,
                        mrp,
                        final_price,
                        category
                    )
                `)
                .order('sort_order');

            if (error) throw error;

            this.displayFeaturedProducts(data || []);
        } catch (error) {
            console.error('Error loading featured products:', error);
            this.showNotification('Error loading featured products', 'error');
        }
    }

    async loadProducts() {
        try {
            const { data, error } = await this.supabase
                .from('products')
                .select('id, product_name, category')
                .eq('is_active', true)
                .order('product_name');

            if (error) throw error;

            this.populateProductSelect(data || []);
        } catch (error) {
            console.error('Error loading products:', error);
        }
    }

    populateProductSelect(products) {
        const select = document.getElementById('productSelect');
        select.innerHTML = '<option value="">Choose a product...</option>';
        
        products.forEach(product => {
            const option = document.createElement('option');
            option.value = product.id;
            option.textContent = `${product.product_name} (${product.category})`;
            select.appendChild(option);
        });
    }

    displayFeaturedProducts(featuredProducts) {
        const container = document.getElementById('featuredProductsList');
        
        if (featuredProducts.length === 0) {
            container.innerHTML = '<p class="no-data">No featured products found.</p>';
            return;
        }

        container.innerHTML = featuredProducts.map(item => `
            <div class="featured-product-item" data-id="${item.id}">
                <div class="product-info">
                    <h3>${item.products?.product_name || 'Unknown Product'}</h3>
                    <p class="category">${item.products?.category || 'Unknown Category'}</p>
                    <p class="price">₹${item.products?.final_price || item.products?.mrp || 0}</p>
                </div>
                <div class="product-meta">
                    <span class="sort-order">Order: ${item.sort_order}</span>
                    <span class="status ${item.is_active ? 'active' : 'inactive'}">
                        ${item.is_active ? 'Active' : 'Inactive'}
                    </span>
                </div>
                <div class="actions">
                    <button class="btn btn-small btn-secondary" onclick="featuredProductsManager.editFeaturedProduct('${item.id}')">
                        Edit
                    </button>
                    <button class="btn btn-small btn-danger" onclick="featuredProductsManager.deleteFeaturedProduct('${item.id}')">
                        Remove
                    </button>
                </div>
            </div>
        `).join('');
    }

    openModal(editData = null) {
        const modal = document.getElementById('featuredProductModal');
        const title = document.getElementById('modalTitle');
        const form = document.getElementById('featuredProductForm');

        if (editData) {
            title.textContent = 'Edit Featured Product';
            this.currentEditId = editData.id;
            
            // Populate form with existing data
            document.getElementById('productSelect').value = editData.product_id;
            document.getElementById('sortOrder').value = editData.sort_order;
            document.getElementById('isActive').checked = editData.is_active;
        } else {
            title.textContent = 'Add Featured Product';
            this.currentEditId = null;
            form.reset();
        }

        modal.style.display = 'block';
    }

    closeModal() {
        const modal = document.getElementById('featuredProductModal');
        modal.style.display = 'none';
        this.currentEditId = null;
    }

    async handleSubmit(e) {
        e.preventDefault();

        const formData = {
            product_id: document.getElementById('productSelect').value,
            sort_order: parseInt(document.getElementById('sortOrder').value),
            is_active: document.getElementById('isActive').checked
        };

        try {
            if (this.currentEditId) {
                // Update existing
                const { error } = await this.supabase
                    .from('featured_products')
                    .update(formData)
                    .eq('id', this.currentEditId);

                if (error) throw error;
                this.showNotification('Featured product updated successfully', 'success');
            } else {
                // Create new
                const { error } = await this.supabase
                    .from('featured_products')
                    .insert(formData);

                if (error) throw error;
                this.showNotification('Featured product added successfully', 'success');
            }

            this.closeModal();
            this.loadFeaturedProducts();
        } catch (error) {
            console.error('Error saving featured product:', error);
            this.showNotification('Error saving featured product', 'error');
        }
    }

    async editFeaturedProduct(id) {
        try {
            const { data, error } = await this.supabase
                .from('featured_products')
                .select('*')
                .eq('id', id)
                .single();

            if (error) throw error;

            this.openModal(data);
        } catch (error) {
            console.error('Error loading featured product for edit:', error);
            this.showNotification('Error loading featured product', 'error');
        }
    }

    async deleteFeaturedProduct(id) {
        if (!confirm('Are you sure you want to remove this featured product?')) {
            return;
        }

        try {
            const { error } = await this.supabase
                .from('featured_products')
                .delete()
                .eq('id', id);

            if (error) throw error;

            this.showNotification('Featured product removed successfully', 'success');
            this.loadFeaturedProducts();
        } catch (error) {
            console.error('Error deleting featured product:', error);
            this.showNotification('Error removing featured product', 'error');
        }
    }

    showNotification(message, type = 'info') {
        // Simple notification system
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.featuredProductsManager = new FeaturedProductsManager();
});

// Global functions for onclick handlers
function closeModal() {
    if (window.featuredProductsManager) {
        window.featuredProductsManager.closeModal();
    }
}

