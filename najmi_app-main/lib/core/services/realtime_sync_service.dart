import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:contracto_app/core/network/supabase_service.dart';

/// Real-time synchronization service for the mobile app
/// Manages Supabase real-time subscriptions for products, categories, brands, and featured content
class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  // Stream controllers for different data types
  final _productsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _categoriesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _brandsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _featuredProductsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _featuredBrandsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _imageSlidesController = StreamController<List<Map<String, dynamic>>>.broadcast();

  // Subscription channels
  RealtimeChannel? _productsChannel;
  RealtimeChannel? _categoriesChannel;
  RealtimeChannel? _brandsChannel;
  RealtimeChannel? _featuredProductsChannel;
  RealtimeChannel? _featuredBrandsChannel;
  RealtimeChannel? _imageSlidesChannel;

  // Throttle timers to prevent UI thrashing
  Timer? _productsThrottle;
  Timer? _categoriesThrottle;
  Timer? _brandsThrottle;
  Timer? _featuredProductsThrottle;
  Timer? _featuredBrandsThrottle;
  Timer? _imageSlidesThrottle;

  // Throttle duration
  static const _throttleDuration = Duration(milliseconds: 500);

  // Public streams
  Stream<List<Map<String, dynamic>>> get productsStream => _productsController.stream;
  Stream<List<Map<String, dynamic>>> get categoriesStream => _categoriesController.stream;
  Stream<List<Map<String, dynamic>>> get brandsStream => _brandsController.stream;
  Stream<List<Map<String, dynamic>>> get featuredProductsStream => _featuredProductsController.stream;
  Stream<List<Map<String, dynamic>>> get featuredBrandsStream => _featuredBrandsController.stream;
  Stream<List<Map<String, dynamic>>> get imageSlidesStream => _imageSlidesController.stream;
  
  // Notification stream (single new notification)
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  RealtimeChannel? _notificationsChannel;

  bool _isInitialized = false;

  /// Initialize all real-time subscriptions
  Future<void> initialize() async {
    if (_isInitialized) {
      print('RealtimeSyncService already initialized');
      return;
    }

    try {
      print('Initializing RealtimeSyncService...');
      
      await _subscribeToProducts();
      await _subscribeToCategories();
      await _subscribeToBrands();
      await _subscribeToFeaturedProducts();
      await _subscribeToFeaturedBrands();
      await _subscribeToImageSlides();

      _isInitialized = true;
      print('RealtimeSyncService initialized successfully');
    } catch (e) {
      print('Error initializing RealtimeSyncService: $e');
      // Don't throw - allow app to continue without real-time sync
    }
  }

  /// Subscribe to products table changes
  Future<void> _subscribeToProducts() async {
    try {
      print('🔌 Attempting to subscribe to products table changes...');
      
      _productsChannel = SupabaseService.client
          .channel('products_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            callback: (payload) {
              print('═══════════════════════════════════════════════');
              print('🔔 DATABASE CHANGE DETECTED IN PRODUCTS TABLE!');
              print('📋 Event Type: ${payload.eventType}');
              print('📦 Old Record: ${payload.oldRecord}');
              print('📦 New Record: ${payload.newRecord}');
              print('═══════════════════════════════════════════════');
              _throttledProductsRefresh();
            },
          )
          .subscribe();

      print('✅ Successfully subscribed to products table changes');
      
    } catch (e, stackTrace) {
      print('❌ Error subscribing to products: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Subscribe to categories table changes
  Future<void> _subscribeToCategories() async {
    try {
      _categoriesChannel = SupabaseService.client
          .channel('categories_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'categories',
            callback: (payload) {
              print('Categories change detected: ${payload.eventType}');
              _throttledCategoriesRefresh();
            },
          )
          .subscribe();

      print('Subscribed to categories changes');
    } catch (e) {
      print('Error subscribing to categories: $e');
    }
  }

  /// Subscribe to brands table changes
  Future<void> _subscribeToBrands() async {
    try {
      _brandsChannel = SupabaseService.client
          .channel('brands_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'brands',
            callback: (payload) {
              print('Brands change detected: ${payload.eventType}');
              _throttledBrandsRefresh();
            },
          )
          .subscribe();

      print('Subscribed to brands changes');
    } catch (e) {
      print('Error subscribing to brands: $e');
    }
  }

  /// Subscribe to featured_products table changes
  Future<void> _subscribeToFeaturedProducts() async {
    try {
      _featuredProductsChannel = SupabaseService.client
          .channel('featured_products_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'featured_products',
            callback: (payload) {
              print('Featured products change detected: ${payload.eventType}');
              _throttledFeaturedProductsRefresh();
            },
          )
          .subscribe();

      print('Subscribed to featured_products changes');
    } catch (e) {
      print('Error subscribing to featured_products: $e');
    }
  }

  /// Subscribe to featured_brands table changes
  Future<void> _subscribeToFeaturedBrands() async {
    try {
      _featuredBrandsChannel = SupabaseService.client
          .channel('featured_brands_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'featured_brands',
            callback: (payload) {
              print('Featured brands change detected: ${payload.eventType}');
              _throttledFeaturedBrandsRefresh();
            },
          )
          .subscribe();

      print('Subscribed to featured_brands changes');
    } catch (e) {
      print('Error subscribing to featured_brands: $e');
    }
  }

  /// Subscribe to image_slides table changes
  Future<void> _subscribeToImageSlides() async {
    try {
      _imageSlidesChannel = SupabaseService.client
          .channel('image_slides_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'image_slides',
            callback: (payload) {
              print('Image slides change detected: ${payload.eventType}');
              _throttledImageSlidesRefresh();
            },
          )
          .subscribe();

      print('Subscribed to image_slides changes');
    } catch (e) {
      print('Error subscribing to image_slides: $e');
    }
  }

  /// Throttled products refresh
  void _throttledProductsRefresh() {
    _productsThrottle?.cancel();
    _productsThrottle = Timer(_throttleDuration, () async {
      try {
        final products = await SupabaseService.client
            .from('products')
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false);
        _productsController.add(List<Map<String, dynamic>>.from(products));
      } catch (e) {
        print('Error refreshing products: $e');
      }
    });
  }

  /// Throttled categories refresh
  void _throttledCategoriesRefresh() {
    _categoriesThrottle?.cancel();
    _categoriesThrottle = Timer(_throttleDuration, () async {
      try {
        final categories = await SupabaseService.client
            .from('categories')
            .select()
            .eq('is_active', true)
            .order('name');
        _categoriesController.add(List<Map<String, dynamic>>.from(categories));
      } catch (e) {
        print('Error refreshing categories: $e');
      }
    });
  }

  /// Throttled brands refresh
  void _throttledBrandsRefresh() {
    _brandsThrottle?.cancel();
    _brandsThrottle = Timer(_throttleDuration, () async {
      try {
        final brands = await SupabaseService.client
            .from('brands')
            .select()
            .eq('is_active', true)
            .order('name');
        _brandsController.add(List<Map<String, dynamic>>.from(brands));
      } catch (e) {
        print('Error refreshing brands: $e');
      }
    });
  }

  /// Throttled featured products refresh
  void _throttledFeaturedProductsRefresh() {
    _featuredProductsThrottle?.cancel();
    _featuredProductsThrottle = Timer(_throttleDuration, () async {
      try {
        final featured = await SupabaseService.client
            .from('featured_products')
            .select('''
              id,
              sort_order,
              products!inner(*)
            ''')
            .eq('is_active', true)
            .order('sort_order');
        _featuredProductsController.add(List<Map<String, dynamic>>.from(featured));
      } catch (e) {
        print('Error refreshing featured products: $e');
      }
    });
  }

  /// Throttled featured brands refresh
  void _throttledFeaturedBrandsRefresh() {
    _featuredBrandsThrottle?.cancel();
    _featuredBrandsThrottle = Timer(_throttleDuration, () async {
      try {
        final featured = await SupabaseService.client
            .from('featured_brands')
            .select('''
              id,
              sort_order,
              brands!inner(*)
            ''')
            .eq('is_active', true)
            .order('sort_order');
        _featuredBrandsController.add(List<Map<String, dynamic>>.from(featured));
      } catch (e) {
        print('Error refreshing featured brands: $e');
      }
    });
  }

  /// Throttled image slides refresh
  void _throttledImageSlidesRefresh() {
    _imageSlidesThrottle?.cancel();
    _imageSlidesThrottle = Timer(_throttleDuration, () async {
      try {
        final slides = await SupabaseService.client
            .from('image_slides')
            .select()
            .eq('is_active', true)
            .order('sort_order');
        _imageSlidesController.add(List<Map<String, dynamic>>.from(slides));
      } catch (e) {
        print('Error refreshing image slides: $e');
      }
    });
  }

  /// Subscribe to user-specific notifications
  Future<void> subscribeToUserNotifications(String userId) async {
    if (_notificationsChannel != null) {
      print('Unsubscribing from existing notifications channel...');
      await _notificationsChannel!.unsubscribe();
    }

    try {
      print('========================================');
      print('SUBSCRIBING TO NOTIFICATIONS');
      print('User ID: $userId');
      print('Channel name: public:notifications:userId=eq.$userId');
      print('========================================');
      
      _notificationsChannel = SupabaseService.client
          .channel('public:notifications:userId=eq.$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              print('========================================');
              print('🔔 NEW NOTIFICATION RECEIVED!');
              print('Payload: ${payload.newRecord}');
              print('========================================');
              _notificationController.add(payload.newRecord);
            },
          )
          .subscribe();

      print('Subscribed to user notifications channel successfully');
    } catch (e, stackTrace) {
      print('========================================');
      print('ERROR subscribing to notifications');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('========================================');
    }
  }

  /// Manually trigger a refresh of all data
  Future<void> refreshAll() async {
    print('Manually refreshing all real-time data...');
    _throttledProductsRefresh();
    _throttledCategoriesRefresh();
    _throttledBrandsRefresh();
    _throttledFeaturedProductsRefresh();
    _throttledFeaturedBrandsRefresh();
    _throttledImageSlidesRefresh();
  }

  /// Dispose all subscriptions and clean up resources
  Future<void> dispose() async {
    print('Disposing RealtimeSyncService...');

    // Cancel throttle timers
    _productsThrottle?.cancel();
    _categoriesThrottle?.cancel();
    _brandsThrottle?.cancel();
    _featuredProductsThrottle?.cancel();
    _featuredBrandsThrottle?.cancel();
    _imageSlidesThrottle?.cancel();

    _featuredBrandsThrottle?.cancel();
    _imageSlidesThrottle?.cancel();

    // Unsubscribe from channels
    await _notificationsChannel?.unsubscribe();
    await _productsChannel?.unsubscribe();
    await _categoriesChannel?.unsubscribe();
    await _brandsChannel?.unsubscribe();
    await _featuredProductsChannel?.unsubscribe();
    await _featuredBrandsChannel?.unsubscribe();
    await _imageSlidesChannel?.unsubscribe();

    // Close stream controllers
    await _productsController.close();
    await _categoriesController.close();
    await _brandsController.close();
    await _featuredProductsController.close();
    await _featuredBrandsController.close();
    await _imageSlidesController.close();
    await _notificationController.close();

    _isInitialized = false;
    print('RealtimeSyncService disposed');
  }
}
