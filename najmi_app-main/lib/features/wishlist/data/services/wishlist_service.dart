import 'package:contracto_app/core/network/supabase_service.dart';

class WishlistService {
  // Singleton pattern
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  // Get wishlist items for current user from database
  Future<List<Map<String, dynamic>>> getWishlistItems() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        print('WishlistService: No authenticated user');
        return [];
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        print('WishlistService: User not found in database');
        return [];
      }

      final userId = userData['id'];

      // Fetch wishlist items from database with product details
      final wishlistData = await SupabaseService.client
          .from('wishlist')
          .select('''
            id,
            product_id,
            created_at,
            products (
              id,
              product_id,
              product_name,
              category,
              subcategory,
              description,
              is_active,
              created_at,
              updated_at
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('WishlistService: Fetched ${wishlistData.length} wishlist items');

      // Transform to return product data with wishlist metadata
      List<Map<String, dynamic>> items = [];
      for (var item in wishlistData) {
        final product = item['products'];
        if (product != null) {
          items.add({
            'wishlist_id': item['id'],
            'id': product['id'],
            'product_id': product['product_id'],
            'name': product['product_name'],
            'category': product['category'] ?? 'General',
            'subcategory': product['subcategory'] ?? '',
            'description': product['description'] ?? '',
            'specifications': product['description'] ?? '',
            'image': 'assets/images/contracto.png', // Default image
            'rating': 4.5, // Default rating
            'reviews': 0,
            'brand': 'Contracto',
            'model': product['product_id'],
            'inStock': product['is_active'] ?? true,
            'created_at': item['created_at'],
          });
        }
      }

      return items;
    } catch (e) {
      print('WishlistService: Error fetching wishlist: $e');
      return [];
    }
  }

  // Add product to wishlist
  Future<bool> addToWishlist(String productId) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        print('WishlistService: No authenticated user');
        return false;
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        print('WishlistService: User not found in database');
        return false;
      }

      final userId = userData['id'];

      // Check if product already in wishlist
      final existing = await SupabaseService.client
          .from('wishlist')
          .select('id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        print('WishlistService: Product already in wishlist');
        return true; // Already in wishlist, consider it success
      }

      // Add to wishlist
      await SupabaseService.client.from('wishlist').insert({
        'user_id': userId,
        'product_id': productId,
      });

      print('WishlistService: Product added to wishlist');
      return true;
    } catch (e) {
      print('WishlistService: Error adding to wishlist: $e');
      return false;
    }
  }

  // Remove product from wishlist
  Future<bool> removeFromWishlist(String wishlistId) async {
    try {
      await SupabaseService.client
          .from('wishlist')
          .delete()
          .eq('id', wishlistId);

      print('WishlistService: Product removed from wishlist');
      return true;
    } catch (e) {
      print('WishlistService: Error removing from wishlist: $e');
      return false;
    }
  }

  // Remove product from wishlist by product ID
  Future<bool> removeFromWishlistByProductId(String productId) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        return false;
      }

      final userId = userData['id'];

      await SupabaseService.client
          .from('wishlist')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);

      print('WishlistService: Product removed from wishlist by product ID');
      return true;
    } catch (e) {
      print('WishlistService: Error removing from wishlist: $e');
      return false;
    }
  }

  // Check if product is in wishlist
  Future<bool> isInWishlist(String productId) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        return false;
      }

      final userId = userData['id'];

      final existing = await SupabaseService.client
          .from('wishlist')
          .select('id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return existing != null;
    } catch (e) {
      print('WishlistService: Error checking wishlist: $e');
      return false;
    }
  }

  // Get wishlist count
  Future<int> getWishlistCount() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        return 0;
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        return 0;
      }

      final userId = userData['id'];

      final count = await SupabaseService.client
          .from('wishlist')
          .select('id')
          .eq('user_id', userId);

      return count.length;
    } catch (e) {
      print('WishlistService: Error getting wishlist count: $e');
      return 0;
    }
  }
}
