import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/core/services/realtime_sync_service.dart';
import 'package:contracto_app/core/services/cache_manager.dart';
import 'package:contracto_app/core/services/sync_error_handler.dart';
import 'dart:async';

class ProductService {
  final _supabase = SupabaseService.instance;
  final _realtimeSync = RealtimeSyncService();
  final _cacheManager = CacheManager();
  final _errorHandler = SyncErrorHandler();
  
  StreamSubscription? _productsSubscription;
  List<ProductModel>? _cachedProducts;

  /// Initialize real-time sync for products
  void initializeRealtimeSync() {
    _productsSubscription = _realtimeSync.productsStream.listen((products) {
      print('Products updated via real-time sync');
      _cachedProducts = products.map((json) => ProductModel.fromJson(json)).toList();
      _cacheManager.markProductsCacheFresh();
    });
  }

  /// Dispose real-time subscription
  void dispose() {
    _productsSubscription?.cancel();
  }

  Future<List<ProductModel>> getProducts({bool forceRefresh = false}) async {
    try {
      // Check cache first unless force refresh
      if (!forceRefresh && _cachedProducts != null && await _cacheManager.isProductsCacheValid()) {
        print('Returning cached products');
        return _cachedProducts!;
      }

      // Fetch fresh data with retry logic
      return await _errorHandler.executeWithRetry(
        operation: () async {
          final response = await _supabase.getProducts();
          final products = response.map((json) => ProductModel.fromJson(json)).toList();
          
          // Update cache
          _cachedProducts = products;
          await _cacheManager.markProductsCacheFresh();
          
          return products;
        },
        operationName: 'Get Products',
      );
    } catch (e) {
      _errorHandler.logError('ProductService.getProducts', e);
      
      // Return cached data if available, even if expired
      if (_cachedProducts != null) {
        print('Returning stale cached products due to error');
        return _cachedProducts!;
      }
      
      rethrow;
    }
  }

  Future<List<ProductModel>> getProductsByBrand(String brandId) async {
    try {
      // Query for products that have this brand in either brand_id or brand_ids
      final response = await SupabaseService.client
          .from('products')
          .select()
          .or('brand_id.eq.$brandId,brand_ids.cs.["$brandId"]')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching products by brand: $e');
      rethrow;
    }
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      var queryBuilder = SupabaseService.client
          .from('products')
          .select()
          .eq('is_active', true);

      // Split the search query into individual words for word-by-word matching
      final words = query.trim().split(RegExp(r'\s+'));
      
      for (final word in words) {
        if (word.isNotEmpty) {
          // Each word MUST exist in either product_name or subcategory
          queryBuilder = queryBuilder.or('product_name.ilike.%$word%,subcategory.ilike.%$word%');
        }
      }

      final response = await queryBuilder
          .order('product_name')
          .limit(50);

      final products =
          response.map((json) => ProductModel.fromJson(json)).toList();

      return products;
    } catch (e) {
      print('Error searching products: $e');
      rethrow;
    }
  }

  Future<List<ProductModel>> searchProductsWithBrands(String query) async {
    try {
      // First, search for products by name/description
      final products = await searchProducts(query);

      // Then, for each product, find similar products across different brands
      final similarProducts = <ProductModel>[];

      for (final product in products) {
        // Search for products with similar names across all brands
        final similarResponse = await SupabaseService.client
            .from('products')
            .select()
            .ilike('product_name',
                '%${product.productName.split(' ').take(2).join(' ')}%')
            .eq('is_active', true)
            .neq('id', product.id)
            .order('product_name')
            .limit(5);

        final similar =
            similarResponse.map((json) => ProductModel.fromJson(json)).toList();
        similarProducts.addAll(similar);
      }

      // Combine and remove duplicates
      final allProducts = [...products, ...similarProducts];
      final uniqueProducts = <String, ProductModel>{};

      for (final product in allProducts) {
        if (!uniqueProducts.containsKey(product.productId)) {
          uniqueProducts[product.productId] = product;
        }
      }

      return uniqueProducts.values.toList();
    } catch (e) {
      print('Error searching products with brands: $e');
      rethrow;
    }
  }

  Future<List<ProductModel>> getProductsByCategory(String category) async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select()
          .eq('category', category)
          .eq('is_active', true)
          .order('product_name');

      return response.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching products by category: $e');
      rethrow;
    }
  }

  Future<ProductModel?> getProductById(String productId) async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      print('Error fetching product by ID: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getProductBrands(
      String productName) async {
    try {
      // Search for products with similar names across all brands
      final response = await SupabaseService.client
          .from('products')
          .select('''
            id,
            product_name,
            brand_id,
            brands!inner(
              id,
              name,
              logo_url,
              description
            )
          ''')
          .ilike('product_name', '%$productName%')
          .eq('is_active', true)
          .order('product_name');

      return response.map((json) => Map<String, dynamic>.from(json)).toList();
    } catch (e) {
      print('Error fetching product brands: $e');
      rethrow;
    }
  }

  /// Get products by multiple brand IDs
  Future<List<ProductModel>> getProductsByBrandIds(List<String> brandIds) async {
    try {
      if (brandIds.isEmpty) return [];

      final response = await SupabaseService.client
          .from('products')
          .select()
          .inFilter('brand_id', brandIds)
          .eq('is_active', true)
          .order('product_name');

      return response.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching products by brand IDs: $e');
      return [];
    }
  }

  Future<List<ProductModel>> getFeaturedProducts({bool forceRefresh = false}) async {
    try {
      return await _errorHandler.executeWithRetry(
        operation: () async {
          final response = await SupabaseService.client.from('featured_products').select('''
            id,
            sort_order,
            products!inner(
              id,
              product_id,
              product_name,
              description,
              mrp,
              final_price,
              photos,
              category,
              subcategory,
              brand_id,
              is_active,
              stock_status,
              stock_quantity,
              is_returnable,
              created_at,
              updated_at
            )
          ''').eq('is_active', true).order('sort_order').limit(20);

          final List<ProductModel> featuredProducts = [];
          for (final item in response) {
            if (item['products'] != null) {
              featuredProducts.add(ProductModel.fromJson(item['products']));
            }
          }

          return featuredProducts;
        },
        operationName: 'Get Featured Products',
      );
    } catch (e) {
      _errorHandler.logError('ProductService.getFeaturedProducts', e);
      print('Error fetching featured products: $e');
      // Fallback to regular products if featured table doesn't exist
      return getProducts();
    }
  }

  Future<Map<String, int>> getProductInventory(String productId) async {
    try {
      final response = await SupabaseService.client
          .from('inventory')
          .select('quality_option, current_stock')
          .eq('product_id', productId);

      final Map<String, int> inventory = {};
      for (final item in response) {
        final option = item['quality_option']?.toString() ?? '';
        final stock = (item['current_stock'] as num?)?.toInt() ?? 0;
        inventory[option] = stock;
      }
      return inventory;
    } catch (e) {
      print('Error fetching product inventory: $e');
      return {};
    }
  }
}
