import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'product_model.dart';

// Pagination state
final productsPageProvider = StateProvider<int>((ref) => 0); // 0-indexed page number
final productsPerPage = 100;

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final supabase = ref.watch(supabaseProvider);
    final page = ref.watch(productsPageProvider);
    
    // Calculate offset for pagination
    final offset = page * productsPerPage;
    
    final response = await supabase
        .from('products')
        .select('*, brands(name)')
        .order('created_at', ascending: false)
        .range(offset, offset + productsPerPage - 1); // Fetch only 100 products per page
    
    return (response as List).map((json) => Product.fromJson(json)).toList();
  }

  Future<Product?> addProduct(Product product, dynamic imageFile) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      List<String> photos = List.from(product.photos ?? []);
      
      if (imageFile != null) {
        try {
          final bytes = await imageFile.readAsBytes();
          final fileExt = imageFile.name.split('.').last;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final path = 'products/$fileName';
          
          await supabase.storage.from('product-photos').uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
              );
           final imageUrl = supabase.storage.from('product-photos').getPublicUrl(path);
           photos.add(imageUrl);
        } catch (e) {
          print('DEBUG: Storage upload failed (bucket may not exist): $e');
          print('DEBUG: Continuing without image upload.');
          // Continue without image upload
        }
      }
      
      final productWithImage = product.copyWith(photos: photos);
      final json = productWithImage.toJson();
      json.remove('id'); 
      
      final response = await supabase.from('products').insert(json).select();
      print('DEBUG: Product inserted successfully: $response');
      ref.invalidateSelf();
      
      if (response != null && response is List && response.isNotEmpty) {
        return Product.fromJson(response.first);
      }
      return null;
    } catch (e, st) {
      print('DEBUG: Error adding product: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
  
  Future<void> updateProduct(Product product, dynamic imageFile) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      List<String> photos = product.photos ?? [];
      
      if (imageFile != null) {
        try {
          print('DEBUG: Uploading new image for product: ${product.id}');
          final bytes = await imageFile.readAsBytes();
          final fileExt = imageFile.name.split('.').last;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final path = 'products/$fileName';
          
          await supabase.storage.from('product-photos').uploadBinary(
            path, 
            bytes, 
            fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true)
          );
          
          final imageUrl = supabase.storage.from('product-photos').getPublicUrl(path);
          print('DEBUG: New image URL: $imageUrl');
          
          // We replace the thumbnail (first image) with the new one
          if (photos.isEmpty) {
            photos = [imageUrl];
          } else {
            photos = [imageUrl, ...photos.skip(1)];
          }
        } catch (e) {
          print('DEBUG: Storage upload failed (bucket may not exist): $e');
          print('DEBUG: Continuing without image upload.');
          // Continue without image upload
        }
      }

      final updateData = product.copyWith(photos: photos).toJson();
      // Ensure ID is not in the update payload
      updateData.remove('id');
      
      print('DEBUG: Updating product ${product.id} with data: $updateData');
      
      await supabase.from('products').update(updateData).eq('id', product.id);
      print('DEBUG: Product updated successfully');
      
      ref.invalidateSelf();
    } catch (e, st) {
      print('DEBUG: Error updating product: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      print('DEBUG: Deleting product $id');
      await supabase.from('products').delete().eq('id', id);
      print('DEBUG: Product deleted successfully');
      ref.invalidateSelf();
    } catch (e, st) {
      print('DEBUG: Error deleting product: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Bulk delete multiple products
  Future<void> bulkDeleteProducts(List<String> ids) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      print('DEBUG: Bulk deleting ${ids.length} products');
      for (final id in ids) {
        await supabase.from('products').delete().eq('id', id);
      }
      print('DEBUG: Bulk delete completed successfully');
      ref.invalidateSelf();
    } catch (e, st) {
      print('DEBUG: Error in bulk delete: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Bulk update product status (activate/deactivate)
  Future<void> bulkUpdateStatus(List<String> ids, bool isActive) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      print('DEBUG: Bulk updating status for ${ids.length} products to $isActive');
      for (final id in ids) {
        await supabase.from('products').update({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      }
      print('DEBUG: Bulk status update completed successfully');
      ref.invalidateSelf();
    } catch (e, st) {
      print('DEBUG: Error in bulk status update: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Bulk apply discount to products
  Future<void> bulkApplyDiscount(List<String> ids, double discountPercent) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      print('DEBUG: Bulk applying $discountPercent% discount to ${ids.length} products');
      
      for (final id in ids) {
        // Fetch product to get MRP
        final product = await supabase
            .from('products')
            .select('mrp')
            .eq('id', id)
            .single();
        
        final mrp = (product['mrp'] as num?)?.toDouble();
        if (mrp != null) {
          final finalPrice = double.parse(
            (mrp * (1 - discountPercent / 100)).toStringAsFixed(2),
          );
          
          await supabase.from('products').update({
            'discount_percent': discountPercent,
            'final_price': finalPrice,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', id);
        }
      }
      
      print('DEBUG: Bulk discount application completed successfully');
      ref.invalidateSelf();
    } catch (e, st) {
      print('DEBUG: Error in bulk discount application: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Toggle stock status for a product
  Future<void> toggleStockStatus(String productId, String currentStatus) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      final newStatus = currentStatus == 'in_stock' ? 'out_of_stock' : 'in_stock';
      
      print('DEBUG: Toggling stock status for product $productId from $currentStatus to $newStatus');
      
      await supabase.from('products').update({
        'stock_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);
      
      print('DEBUG: Stock status updated successfully to $newStatus');
      ref.invalidateSelf();
    } catch (e, st) {
      print('DEBUG: Error toggling stock status: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final productsSearchProvider = StateProvider<String>((ref) => '');

final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final searchQuery = ref.watch(productsSearchProvider).trim();

  // No search — return the normal paginated products
  if (searchQuery.isEmpty) {
    return ref.watch(productsProvider);
  }

  // Search active — use a DB-level search across all products
  return ref.watch(_productSearchResultsProvider(searchQuery));
});

/// Searches ALL products in Supabase via ilike (not just the current page).
/// Uses FutureProvider.family so results are keyed per query string.
final _productSearchResultsProvider =
    FutureProvider.family<List<Product>, String>((ref, query) async {
  final supabase = ref.watch(supabaseProvider);
  final q = '%${query.toLowerCase()}%';

  // Run parallel searches on name, productId, category
  final results = await Future.wait([
    supabase
        .from('products')
        .select('*, brands(name)')
        .ilike('product_name', q)
        .limit(100),
    supabase
        .from('products')
        .select('*, brands(name)')
        .ilike('product_id', q)
        .limit(50),
    supabase
        .from('products')
        .select('*, brands(name)')
        .ilike('category', q)
        .limit(50),
  ]);

  // Merge all results and deduplicate by product ID
  final seen = <String>{};
  final merged = <Product>[];
  for (final list in results) {
    for (final json in (list as List)) {
      final p = Product.fromJson(json);
      if (seen.add(p.id)) merged.add(p);
    }
  }
  return merged;
});


// Provider to get total number of pages
final productsTotalPagesProvider = Provider<AsyncValue<int>>((ref) {
  final totalProductsAsync = ref.watch(productsCountProvider);
  return totalProductsAsync.whenData((total) {
    return (total / productsPerPage).ceil(); // Round up to get total pages
  });
});

/// Separate provider to get the *real* total number of products from Supabase.
/// We manually paginate in chunks of 1000 to avoid any row limits on a single
/// select call and get an accurate count.
final productsCountProvider = FutureProvider<int>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  const pageSize = 1000;
  int offset = 0;
  int total = 0;

  while (true) {
    final response = await supabase
        .from('products')
        .select('id')
        .range(offset, offset + pageSize - 1);

    final items = response as List;
    final count = items.length;
    total += count;

    if (count < pageSize) {
      // Last page reached
      break;
    }

    offset += pageSize;
  }

  return total;
});
