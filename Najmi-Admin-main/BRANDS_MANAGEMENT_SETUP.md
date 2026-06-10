# Brands and Products Management Setup Guide

This guide explains how to set up brand and product management in the Najmi Admin Panel.

## Overview

The admin panel needs to:
1. **View all brands** from the database (including inactive ones)
2. **Add new brands** with logo and catalog PDF
3. **Edit existing brands**
4. **Delete brands** (with proper checks)
5. **View products** associated with each brand
6. **Add products** to brands
7. **Manage product-brand relationships**

## Database Setup

### Step 1: Run the Main SQL File

Execute the `brands_and_products_management.sql` file in your Supabase SQL Editor. This will:

- ✅ Create RLS (Row Level Security) policies for admin access to brands and products
- ✅ Create views and functions for easier data retrieval
- ✅ Create indexes for better query performance

**Important:** Make sure you're logged in as an admin user when running these queries.

### Step 2: Verify Setup

After running the SQL file, verify that:

1. **RLS Policies are created:**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'brands';
   SELECT * FROM pg_policies WHERE tablename = 'products';
   ```

2. **Views are created:**
   ```sql
   SELECT * FROM brands_with_product_counts LIMIT 5;
   ```

3. **Functions are created:**
   ```sql
   SELECT get_brand_details_with_products('your-brand-id-here');
   ```

## Quick Reference Queries

For common operations, refer to `brands_queries_quick_reference.sql`. This file contains ready-to-use queries for:

- Viewing all brands with product counts
- Getting products for a specific brand
- Adding/updating/deleting brands
- Adding products to brands
- Searching brands
- And more...

## Using in Flutter Admin Panel

### 1. Fetch All Brands

The admin panel already has a `brandsProvider` in `lib/features/categories/categories_provider.dart`. This provider fetches all brands from the database.

**Note:** The current implementation only shows active brands. To show all brands (including inactive), modify the query:

```dart
final brandsProvider = FutureProvider<List<Brand>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  // Remove the is_active filter to show all brands
  final response = await supabase
      .from('brands')
      .select('*')
      .order('name');
  return (response as List).map((json) => Brand.fromJson(json)).toList();
});
```

### 2. Add a New Brand

```dart
Future<void> addBrand({
  required String name,
  String? description,
  String? logoUrl,
  bool isActive = true,
}) async {
  final supabase = SupabaseConfig.client;
  await supabase.from('brands').insert({
    'name': name,
    'description': description,
    'logo_url': logoUrl,
    'is_active': isActive,
    'sort_order': 0,
  });
}
```

### 3. Update a Brand

```dart
Future<void> updateBrand({
  required String id,
  String? name,
  String? description,
  String? logoUrl,
  bool? isActive,
}) async {
  final supabase = SupabaseConfig.client;
  final updateData = <String, dynamic>{};
  
  if (name != null) updateData['name'] = name;
  if (description != null) updateData['description'] = description;
  if (logoUrl != null) updateData['logo_url'] = logoUrl;
  if (isActive != null) updateData['is_active'] = isActive;
  updateData['updated_at'] = DateTime.now().toIso8601String();
  
  await supabase
      .from('brands')
      .update(updateData)
      .eq('id', id);
}
```

### 4. Get Products for a Brand

```dart
Future<List<Map<String, dynamic>>> getProductsForBrand(String brandId) async {
  final supabase = SupabaseConfig.client;
  
  // Get products where brand_id matches OR brand is in brand_ids array
  final response = await supabase
      .from('products')
      .select('*')
      .or('brand_id.eq.$brandId,brand_ids.cs.["$brandId"]')
      .order('product_name');
  
  return (response as List).cast<Map<String, dynamic>>();
}
```

### 5. Add a Product to a Brand

```dart
Future<void> addProductToBrand({
  required String productName,
  required String brandId,
  String? category,
  String? description,
  double? mrp,
  double? finalPrice,
}) async {
  final supabase = SupabaseConfig.client;
  
  await supabase.from('products').insert({
    'product_name': productName,
    'brand_id': brandId,
    'category': category,
    'description': description,
    'mrp': mrp,
    'final_price': finalPrice,
    'is_active': true,
  });
}
```

## Brand Model Update

The current `Brand` model in `lib/features/categories/category_model.dart` is minimal. Consider updating it to include all fields:

```dart
class Brand {
  final String id;
  final String name;
  final String? logo;
  final String? description;
  final bool isActive;
  final int? sortOrder;
  final String? catalogPdfUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Brand({
    required this.id,
    required this.name,
    this.logo,
    this.description,
    this.isActive = true,
    this.sortOrder,
    this.catalogPdfUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'],
      name: json['name'],
      logo: json['logo_url'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'],
      catalogPdfUrl: json['catalog_pdf_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logo,
      'description': description,
      'is_active': isActive,
      'sort_order': sortOrder,
      'catalog_pdf_url': catalogPdfUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
```

## Troubleshooting

### Issue: "403 Forbidden" when trying to access brands

**Solution:** Make sure you've run the `brands_and_products_management.sql` file and that your user has the `admin` role in the `users` table.

### Issue: Can't see inactive brands

**Solution:** The RLS policies allow admins to see all brands. Make sure:
1. You're logged in as an admin user
2. Your user record in the `users` table has `role = 'admin'`
3. The RLS policies have been created successfully

### Issue: Can't add products to a brand

**Solution:** 
1. Verify the brand exists in the database
2. Check that the RLS policies for products INSERT are in place
3. Ensure you're authenticated as an admin user

## Next Steps

1. ✅ Run `brands_and_products_management.sql` in Supabase SQL Editor
2. ✅ Update the `Brand` model to include all fields
3. ✅ Update `brands_screen.dart` to show all brands (including inactive)
4. ✅ Add functionality to add/edit/delete brands
5. ✅ Add functionality to view products for each brand
6. ✅ Add functionality to add products to brands

## Support

If you encounter any issues, check:
- Supabase logs for RLS policy violations
- Browser console for JavaScript errors
- Flutter debug console for API errors

