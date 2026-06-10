# Categories Sync Setup Guide

## Overview
This setup will populate your categories table with data from your products table and keep them synchronized automatically.

## Step 1: Run the SQL Script
1. Open your Supabase SQL Editor
2. Copy and paste the entire contents of `sync_categories_from_products.sql`
3. Click "Run" to execute the script

## What the Script Does:

### 🔄 **Automatic Synchronization**
- **Products → Categories**: When you add/edit/delete products, categories are automatically updated
- **Categories → Products**: When you rename/delete categories, products are automatically updated
- **Bidirectional Sync**: Changes in either table reflect in the other

### 📊 **Categories with Counts View**
- Shows each category with:
  - Product count
  - List of subcategories
  - All category details (name, description, thumbnail, etc.)

### 🎯 **Key Features**
- **Empty & Repopulate**: Clears existing categories and creates new ones from products
- **Real-time Sync**: Automatic triggers keep data synchronized
- **Manual Sync**: Button in admin panel to manually sync if needed
- **Thumbnail Support**: Categories can have thumbnails uploaded
- **Product Counts**: Shows how many products are in each category

## Step 2: Test the Integration

### In the Admin Panel:
1. Go to **Categories** page
2. You should see all categories from your products table
3. Each category shows:
   - Thumbnail (if uploaded)
   - Name
   - Description
   - Subcategories (first 3, with count if more)
   - Product count
   - Status
   - Created date

### Test Synchronization:
1. **Add a new product** with a new category → Category should appear automatically
2. **Edit a product's category** → Category should update automatically
3. **Rename a category** in admin panel → All products with that category should update
4. **Click "Sync from Products"** button → Manual sync if needed

## Step 3: Upload Thumbnails (Optional)
1. Click "Add Category" or edit existing category
2. Upload thumbnail image
3. Save changes
4. Thumbnail will appear in the categories table

## Troubleshooting

### If sync doesn't work:
1. Check Supabase logs for errors
2. Ensure RLS policies allow the operations
3. Use the "Sync from Products" button for manual sync
4. Check that the `categories_with_counts` view exists

### If categories don't show:
1. Verify the SQL script ran successfully
2. Check that products have valid category names
3. Ensure the view has proper permissions

## Database Structure

### Tables Created/Modified:
- `categories` - Main categories table
- `categories_with_counts` - View with counts and subcategories

### Functions Created:
- `sync_categories_from_products()` - Syncs categories when products change
- `sync_products_from_categories()` - Syncs products when categories change
- `manual_sync_categories()` - Manual sync function

### Triggers Created:
- Auto-sync on product insert/update/delete
- Auto-sync on category update/delete

## Benefits:
✅ **Single Source of Truth**: Categories come from actual products
✅ **Automatic Updates**: No manual maintenance needed
✅ **Real-time Sync**: Changes reflect immediately
✅ **Rich Data**: Shows product counts and subcategories
✅ **Admin Control**: Can still manage categories manually
✅ **Thumbnail Support**: Visual category representation
