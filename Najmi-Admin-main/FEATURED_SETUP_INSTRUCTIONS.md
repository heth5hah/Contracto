# Featured Section Setup Instructions

## 🚀 Quick Setup

### 1. **Run Database Migration**
Execute the SQL in `featured_tables_migration.sql` in your Supabase SQL editor to create the required tables:

- `featured_products` - Stores featured product selections
- `featured_brands` - Stores featured brand selections  
- `image_slides` - Stores promotional image slides

### 2. **Verify Storage Bucket**
Ensure the `product-photos` storage bucket exists in your Supabase project for image uploads.

### 3. **Access the Page**
Navigate to `/pages/featured.html` in your admin panel.

## ✅ What's Ready

- ✅ **Featured Products Management** - Add/edit/delete featured products with search
- ✅ **Featured Brands Management** - Manage featured brand listings
- ✅ **Image Slides Management** - Upload and manage promotional slides
- ✅ **Full CRUD Operations** - Complete create, read, update, delete functionality
- ✅ **Responsive Design** - Works on all devices
- ✅ **Dark Mode Support** - Consistent with your existing theme

## 📱 Features

### Featured Products Tab
- Search and select products with autocomplete
- Set display order and active status
- View product details, pricing, and images
- Manage featured product priority

### Featured Brands Tab  
- Select from existing brands
- Automatic product count display
- Brand priority management
- Status control

### Image Slides Tab
- Drag & drop image upload
- Add titles, descriptions, and click URLs
- Image preview functionality
- Sort order management

## 🔧 Database Schema

The migration creates these tables with proper relationships:

```sql
-- Featured products with foreign key to products table
featured_products (id, product_id, sort_order, is_active, created_at, updated_at)

-- Featured brands with foreign key to brands table  
featured_brands (id, brand_id, sort_order, is_active, created_at, updated_at)

-- Image slides for promotional content
image_slides (id, title, description, image_url, link_url, sort_order, is_active, created_at, updated_at)
```

## 🎯 Next Steps

1. Run the SQL migration
2. Test the featured section functionality
3. Add some featured products and brands
4. Upload promotional image slides
5. Verify everything works as expected

The featured section is now fully integrated with your admin panel!

