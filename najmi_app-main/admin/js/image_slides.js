// Image Slides Management
class ImageSlidesManager {
    constructor() {
        this.supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        this.currentEditId = null;
        this.init();
    }

    async init() {
        this.loadSlides();
        this.loadBrands();
        this.setupEventListeners();
    }

    setupEventListeners() {
        const addBtn = document.getElementById('addSlideBtn');
        const modal = document.getElementById('slideModal');
        const closeBtn = document.querySelector('.close');
        const form = document.getElementById('slideForm');

        addBtn.addEventListener('click', () => this.openModal());
        closeBtn.addEventListener('click', () => this.closeModal());
        
        window.addEventListener('click', (e) => {
            if (e.target === modal) this.closeModal();
        });

        form.addEventListener('submit', (e) => this.handleSubmit(e));
    }

    async loadSlides() {
        try {
            const { data, error } = await this.supabase
                .from('image_slides')
                .select(`
                    *,
                    brands (
                        id,
                        name
                    )
                `)
                .order('sort_order');

            if (error) throw error;

            this.displaySlides(data || []);
            this.updateSlidesPreview(data || []);
        } catch (error) {
            console.error('Error loading slides:', error);
            this.showNotification('Error loading slides', 'error');
        }
    }

    async loadBrands() {
        try {
            const { data, error } = await this.supabase
                .from('brands')
                .select('id, name')
                .eq('is_active', true)
                .order('name');

            if (error) throw error;

            const brandSelect = document.getElementById('slideBrand');
            brandSelect.innerHTML = '<option value="">Select a brand...</option>';
            
            data.forEach(brand => {
                const option = document.createElement('option');
                option.value = brand.id;
                option.textContent = brand.name;
                brandSelect.appendChild(option);
            });
        } catch (error) {
            console.error('Error loading brands:', error);
        }
    }

    displaySlides(slides) {
        const container = document.getElementById('slidesList');
        
        if (slides.length === 0) {
            container.innerHTML = '<p class="no-data">No slides found. Add your first slide to get started!</p>';
            return;
        }

        container.innerHTML = slides.map(slide => `
            <div class="slide-item" data-id="${slide.id}">
                <div class="slide-image">
                    <img src="${slide.image_url}" alt="${slide.title || 'Slide'}" 
                         onerror="this.src='assets/images/placeholder.png'">
                </div>
                <div class="slide-info">
                    <h3>${slide.title || 'Untitled'}</h3>
                    <p class="description">${slide.description || 'No description'}</p>
                    <div class="slide-meta">
                        <span class="sort-order">Order: ${slide.sort_order}</span>
                        <span class="status ${slide.is_active ? 'active' : 'inactive'}">
                            ${slide.is_active ? 'Active' : 'Inactive'}
                        </span>
                    </div>
                    ${slide.link_url ? `<p class="link">Link: <a href="${slide.link_url}" target="_blank">${slide.link_url}</a></p>` : ''}
                    ${slide.brands ? `<p class="brand">Brand: <strong>${slide.brands.name}</strong></p>` : ''}
                </div>
                <div class="actions">
                    <button class="btn btn-small btn-secondary" onclick="imageSlidesManager.editSlide('${slide.id}')">
                        Edit
                    </button>
                    <button class="btn btn-small btn-danger" onclick="imageSlidesManager.deleteSlide('${slide.id}')">
                        Delete
                    </button>
                </div>
            </div>
        `).join('');
    }

    updateSlidesPreview(slides) {
        const container = document.getElementById('slidesPreview');
        const activeSlides = slides.filter(slide => slide.is_active);
        
        if (activeSlides.length === 0) {
            container.innerHTML = '<p class="no-data">No active slides to preview</p>';
            return;
        }

        container.innerHTML = `
            <div class="slides-carousel">
                ${activeSlides.map((slide, index) => `
                    <div class="slide-preview ${index === 0 ? 'active' : ''}" data-index="${index}">
                        <img src="${slide.image_url}" alt="${slide.title || 'Slide'}" 
                             onerror="this.src='assets/images/placeholder.png'">
                        <div class="slide-overlay">
                            <h4>${slide.title || 'Untitled'}</h4>
                            <p>${slide.description || 'No description'}</p>
                        </div>
                    </div>
                `).join('')}
            </div>
            <div class="slides-dots">
                ${activeSlides.map((_, index) => `
                    <span class="dot ${index === 0 ? 'active' : ''}" onclick="imageSlidesManager.showSlide(${index})"></span>
                `).join('')}
            </div>
        `;

        // Auto-rotate slides
        this.startSlideshow(activeSlides.length);
    }

    startSlideshow(slideCount) {
        if (slideCount <= 1) return;
        
        setInterval(() => {
            const currentSlide = document.querySelector('.slide-preview.active');
            const currentIndex = parseInt(currentSlide.dataset.index);
            const nextIndex = (currentIndex + 1) % slideCount;
            this.showSlide(nextIndex);
        }, 4000);
    }

    showSlide(index) {
        const slides = document.querySelectorAll('.slide-preview');
        const dots = document.querySelectorAll('.dot');
        
        slides.forEach((slide, i) => {
            slide.classList.toggle('active', i === index);
        });
        
        dots.forEach((dot, i) => {
            dot.classList.toggle('active', i === index);
        });
    }

    openModal(editData = null) {
        const modal = document.getElementById('slideModal');
        const title = document.getElementById('modalTitle');
        const form = document.getElementById('slideForm');

        if (editData) {
            title.textContent = 'Edit Slide';
            this.currentEditId = editData.id;
            
            // Populate form with existing data
            document.getElementById('slideTitle').value = editData.title || '';
            document.getElementById('slideDescription').value = editData.description || '';
            document.getElementById('slideImageUrl').value = editData.image_url;
            document.getElementById('slideLinkUrl').value = editData.link_url || '';
            document.getElementById('slideBrand').value = editData.brand_id || '';
            document.getElementById('slideSortOrder').value = editData.sort_order;
            document.getElementById('slideIsActive').checked = editData.is_active;
        } else {
            title.textContent = 'Add New Slide';
            this.currentEditId = null;
            form.reset();
            document.getElementById('slideSortOrder').value = this.getNextSortOrder();
        }

        modal.style.display = 'block';
    }

    closeModal() {
        const modal = document.getElementById('slideModal');
        modal.style.display = 'none';
        this.currentEditId = null;
    }

    async getNextSortOrder() {
        try {
            const { data, error } = await this.supabase
                .from('image_slides')
                .select('sort_order')
                .order('sort_order', { ascending: false })
                .limit(1);

            if (error) throw error;
            
            return data && data.length > 0 ? data[0].sort_order + 1 : 0;
        } catch (error) {
            console.error('Error getting next sort order:', error);
            return 0;
        }
    }

    async handleSubmit(e) {
        e.preventDefault();

        const brandId = document.getElementById('slideBrand').value.trim();
        const formData = {
            title: document.getElementById('slideTitle').value.trim() || null,
            description: document.getElementById('slideDescription').value.trim() || null,
            image_url: document.getElementById('slideImageUrl').value.trim(),
            link_url: document.getElementById('slideLinkUrl').value.trim() || null,
            brand_id: brandId || null,
            sort_order: parseInt(document.getElementById('slideSortOrder').value),
            is_active: document.getElementById('slideIsActive').checked
        };

        try {
            if (this.currentEditId) {
                // Update existing
                const { error } = await this.supabase
                    .from('image_slides')
                    .update(formData)
                    .eq('id', this.currentEditId);

                if (error) throw error;
                this.showNotification('Slide updated successfully', 'success');
            } else {
                // Create new
                const { error } = await this.supabase
                    .from('image_slides')
                    .insert(formData);

                if (error) throw error;
                this.showNotification('Slide added successfully', 'success');
            }

            this.closeModal();
            this.loadSlides();
        } catch (error) {
            console.error('Error saving slide:', error);
            this.showNotification('Error saving slide', 'error');
        }
    }

    async editSlide(id) {
        try {
            const { data, error } = await this.supabase
                .from('image_slides')
                .select('*')
                .eq('id', id)
                .single();

            if (error) throw error;

            this.openModal(data);
        } catch (error) {
            console.error('Error loading slide for edit:', error);
            this.showNotification('Error loading slide', 'error');
        }
    }

    async deleteSlide(id) {
        if (!confirm('Are you sure you want to delete this slide?')) {
            return;
        }

        try {
            const { error } = await this.supabase
                .from('image_slides')
                .delete()
                .eq('id', id);

            if (error) throw error;

            this.showNotification('Slide deleted successfully', 'success');
            this.loadSlides();
        } catch (error) {
            console.error('Error deleting slide:', error);
            this.showNotification('Error deleting slide', 'error');
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
    window.imageSlidesManager = new ImageSlidesManager();
});

// Global functions for onclick handlers
function closeSlideModal() {
    if (window.imageSlidesManager) {
        window.imageSlidesManager.closeModal();
    }
}

