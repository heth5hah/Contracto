import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache manager for products, categories, and brands
/// Implements TTL-based caching with real-time invalidation support
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // Cache TTL durations
  static const Duration productsCacheTTL = Duration(minutes: 5);
  static const Duration categoriesCacheTTL = Duration(minutes: 10);
  static const Duration brandsCacheTTL = Duration(minutes: 10);

  // Cache keys
  static const String _productsKey = 'cache_products';
  static const String _productsTimestampKey = 'cache_products_timestamp';
  static const String _categoriesKey = 'cache_categories';
  static const String _categoriesTimestampKey = 'cache_categories_timestamp';
  static const String _brandsKey = 'cache_brands';
  static const String _brandsTimestampKey = 'cache_brands_timestamp';

  SharedPreferences? _prefs;

  /// Initialize the cache manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    print('CacheManager initialized');
  }

  /// Check if products cache is valid
  Future<bool> isProductsCacheValid() async {
    return _isCacheValid(_productsTimestampKey, productsCacheTTL);
  }

  /// Check if categories cache is valid
  Future<bool> isCategoriesCacheValid() async {
    return _isCacheValid(_categoriesTimestampKey, categoriesCacheTTL);
  }

  /// Check if brands cache is valid
  Future<bool> isBrandsCacheValid() async {
    return _isCacheValid(_brandsTimestampKey, brandsCacheTTL);
  }

  /// Generic cache validity check
  Future<bool> _isCacheValid(String timestampKey, Duration ttl) async {
    if (_prefs == null) await initialize();
    
    final timestamp = _prefs!.getInt(timestampKey);
    if (timestamp == null) return false;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cacheTime);

    return difference < ttl;
  }

  /// Invalidate products cache
  Future<void> invalidateProductsCache() async {
    if (_prefs == null) await initialize();
    await _prefs!.remove(_productsKey);
    await _prefs!.remove(_productsTimestampKey);
    print('Products cache invalidated');
  }

  /// Invalidate categories cache
  Future<void> invalidateCategoriesCache() async {
    if (_prefs == null) await initialize();
    await _prefs!.remove(_categoriesKey);
    await _prefs!.remove(_categoriesTimestampKey);
    print('Categories cache invalidated');
  }

  /// Invalidate brands cache
  Future<void> invalidateBrandsCache() async {
    if (_prefs == null) await initialize();
    await _prefs!.remove(_brandsKey);
    await _prefs!.remove(_brandsTimestampKey);
    print('Brands cache invalidated');
  }

  /// Invalidate all caches
  Future<void> invalidateAllCaches() async {
    await invalidateProductsCache();
    await invalidateCategoriesCache();
    await invalidateBrandsCache();
    print('All caches invalidated');
  }

  /// Update cache timestamp
  Future<void> updateCacheTimestamp(String timestampKey) async {
    if (_prefs == null) await initialize();
    await _prefs!.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Mark products cache as fresh
  Future<void> markProductsCacheFresh() async {
    await updateCacheTimestamp(_productsTimestampKey);
  }

  /// Mark categories cache as fresh
  Future<void> markCategoriesCacheFresh() async {
    await updateCacheTimestamp(_categoriesTimestampKey);
  }

  /// Mark brands cache as fresh
  Future<void> markBrandsCacheFresh() async {
    await updateCacheTimestamp(_brandsTimestampKey);
  }

  /// Clear all cache data
  Future<void> clearAll() async {
    if (_prefs == null) await initialize();
    await _prefs!.clear();
    print('All cache data cleared');
  }
}
