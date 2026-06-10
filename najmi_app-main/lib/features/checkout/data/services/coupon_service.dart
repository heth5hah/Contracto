import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/checkout/data/models/coupon_model.dart';

class CouponService {
  final _supabase = SupabaseService.client;

  /// Validate and fetch coupon by code
  Future<CouponModel?> validateCoupon(String code, double orderValue, {String? userEmail, List<dynamic>? cartItems}) async {
    try {
      print('DIAGNOSTIC: Validating coupon code: $code for order value: $orderValue');
      final response = await _supabase
          .from('coupons')
          .select()
          .ilike('code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();
      
      print('DIAGNOSTIC: Database response: $response');

      if (response == null) {
        throw Exception('Invalid coupon code');
      }

      final coupon = CouponModel.fromJson(response);

      // Check if coupon is valid
      if (!coupon.isValid) {
        print('DIAGNOSTIC: Coupon ${coupon.code} is NOT valid.');
        print('DIAGNOSTIC: isActive: ${coupon.isActive}');
        print('DIAGNOSTIC: validFrom: ${coupon.validFrom} (UTC: ${coupon.validFrom.toUtc()})');
        print('DIAGNOSTIC: validTo: ${coupon.validTo} (UTC: ${coupon.validTo?.toUtc()})');
        print('DIAGNOSTIC: now: ${DateTime.now()} (UTC: ${DateTime.now().toUtc()})');
        print('DIAGNOSTIC: timesUsed: ${coupon.timesUsed}, usageLimit: ${coupon.usageLimit}');
        throw Exception('Coupon has expired or is no longer valid');
      }

      if (coupon.applicableUsers.isNotEmpty) {
        if (userEmail == null || !coupon.applicableUsers.contains(userEmail)) {
          throw Exception('Coupon is not applicable for your account');
        }
      }

      if (coupon.applicableProducts.isNotEmpty) {
        if (cartItems == null || cartItems.isEmpty) {
          throw Exception('Coupon is not applicable to any item in your cart');
        }
        bool hasApplicableProduct = false;
        for (final item in cartItems) {
          if (coupon.applicableProducts.contains(item.product.id)) {
            hasApplicableProduct = true;
            break;
          }
        }
        if (!hasApplicableProduct) {
          throw Exception('Coupon is not applicable to any item in your cart');
        }
      }

      // Check minimum order value
      if (orderValue < coupon.minOrderValue) {
        print('DIAGNOSTIC: Min Order Value mismatch. Req: ${coupon.minOrderValue}, Got: $orderValue');
        throw Exception(
            'Minimum order value of ₹${coupon.minOrderValue.toStringAsFixed(0)} required');
      }

      return coupon;
    } catch (e) {
      print('Error validating coupon: $e');
      rethrow;
    }
  }

  /// Apply coupon and get discount amount
  Future<double> applyCoupon(String code, double orderValue, {String? userEmail, List<dynamic> cartItems = const []}) async {
    try {
      final coupon = await validateCoupon(code, orderValue, userEmail: userEmail, cartItems: cartItems);
      if (coupon == null) return 0;

      return coupon.calculateDiscount(orderValue, cartItems: cartItems);
    } catch (e) {
      print('Error applying coupon: $e');
      return 0;
    }
  }

  /// Increment coupon usage count
  Future<void> incrementCouponUsage(String couponId) async {
    try {
      await _supabase.rpc('increment_coupon_usage', params: {'coupon_id': couponId});
    } catch (e) {
      print('Error incrementing coupon usage: $e');
      // Don't throw - this is not critical
    }
  }

  /// Get all active coupons (for display purposes)
  Future<List<CouponModel>> getActiveCoupons({String? userEmail, List<dynamic>? cartItems}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Fetch ALL active coupons first, then filter client-side
      // This avoids issues with null valid_to (never-expiring coupons)
      final response = await _supabase
          .from('coupons')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final all = (response as List)
          .map((json) => CouponModel.fromJson(json))
          .toList();

      // Keep coupons that: have no expiry (valid_to == null) OR haven't expired yet
      final active = all.where((c) {
        if (c.validTo != null && c.validTo!.toUtc().isBefore(DateTime.now().toUtc())) {
          return false; // Expired
        }

        if (c.applicableUsers.isNotEmpty) {
          if (userEmail == null || !c.applicableUsers.contains(userEmail)) {
            return false;
          }
        }

        if (c.applicableProducts.isNotEmpty) {
          if (cartItems == null || cartItems.isEmpty) {
            return false;
          }
          bool hasApplicableProduct = false;
          for (final item in cartItems) {
            if (c.applicableProducts.contains(item.product.id)) {
              hasApplicableProduct = true;
              break;
            }
          }
          if (!hasApplicableProduct) {
            return false;
          }
        }

        return true;
      }).toList();

      print('📦 Coupons fetched: ${all.length}, active after filter: ${active.length}');
      for (final c in all) {
        print('  Coupon: ${c.code} | active=${c.isActive} | validTo=${c.validTo}');
      }

      return active;
    } catch (e) {
      print('Error fetching active coupons: $e');
      return [];
    }
  }
}

