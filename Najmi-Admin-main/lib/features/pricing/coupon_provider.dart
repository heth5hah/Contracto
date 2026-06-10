import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

// Coupon Model
class Coupon {
  final String id;
  final String code;
  final String? description;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final double minOrderValue;
  final double? maxDiscount;
  final DateTime validFrom;
  final DateTime? validTo;
  final int? usageLimit;
  final int timesUsed;
  final bool isActive;
  final DateTime createdAt;
  final List<String> applicableUsers;
  final List<String> applicableProducts;

  Coupon({
    required this.id,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0,
    this.maxDiscount,
    required this.validFrom,
    this.validTo,
    this.usageLimit,
    this.timesUsed = 0,
    this.isActive = true,
    required this.createdAt,
    this.applicableUsers = const [],
    this.applicableProducts = const [],
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'],
      code: json['code'],
      description: json['description'],
      discountType: json['discount_type'],
      discountValue: (json['discount_value'] as num).toDouble(),
      minOrderValue: (json['min_order_value'] as num?)?.toDouble() ?? 0,
      maxDiscount: (json['max_discount'] as num?)?.toDouble(),
      validFrom: DateTime.parse(json['valid_from']),
      validTo: json['valid_to'] != null ? DateTime.parse(json['valid_to']) : null,
      usageLimit: json['usage_limit'],
      timesUsed: json['times_used'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      applicableUsers: (json['applicable_users'] as List?)?.map((e) => e.toString()).toList() ?? [],
      applicableProducts: (json['applicable_products'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'description': description,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      'max_discount': maxDiscount,
      'valid_from': validFrom.toUtc().toIso8601String(),
      'valid_to': validTo?.toUtc().toIso8601String(),
      'usage_limit': usageLimit,
      'is_active': isActive,
      'applicable_users': applicableUsers,
      'applicable_products': applicableProducts,
    };
  }
}

// Provider for coupons list
final couponsProvider = FutureProvider<List<Coupon>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    final response = await supabase
        .from('coupons')
        .select('*')
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => Coupon.fromJson(json)).toList();
  } catch (e) {
    print('Error fetching coupons: $e');
    return [];
  }
});

// Coupon management service
final couponManagementProvider = Provider((ref) => CouponManagementService(ref));

class CouponManagementService {
  final Ref ref;
  
  CouponManagementService(this.ref);
  
  Future<void> createCoupon(Coupon coupon) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase.from('coupons').insert(coupon.toJson());
    ref.invalidate(couponsProvider);
  }
  
  Future<void> updateCoupon(String id, Coupon coupon) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase
        .from('coupons')
        .update(coupon.toJson())
        .eq('id', id);
    
    ref.invalidate(couponsProvider);
  }
  
  Future<void> deleteCoupon(String id) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase.from('coupons').delete().eq('id', id);
    ref.invalidate(couponsProvider);
  }
  
  Future<void> toggleCouponStatus(String id, bool isActive) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase
        .from('coupons')
        .update({'is_active': isActive})
        .eq('id', id);
    
    ref.invalidate(couponsProvider);
  }
  
  // Validate coupon code
  Future<Map<String, dynamic>> validateCoupon(String code, double orderAmount) async {
    final supabase = ref.read(supabaseProvider);
    
    try {
      final response = await supabase
          .from('coupons')
          .select('*')
          .eq('code', code)
          .eq('is_active', true)
          .single();
      
      final coupon = Coupon.fromJson(response);
      
      // Check validity
      final now = DateTime.now();
      if (now.isBefore(coupon.validFrom)) {
        return {'valid': false, 'message': 'Coupon not yet valid'};
      }
      if (coupon.validTo != null && now.isAfter(coupon.validTo!)) {
        return {'valid': false, 'message': 'Coupon expired'};
      }
      
      // Check usage limit
      if (coupon.usageLimit != null && coupon.timesUsed >= coupon.usageLimit!) {
        return {'valid': false, 'message': 'Coupon usage limit reached'};
      }
      
      // Check minimum order amount
      if (orderAmount < coupon.minOrderValue) {
        return {
          'valid': false,
          'message': 'Minimum order amount ₹${coupon.minOrderValue.toStringAsFixed(2)} required'
        };
      }
      
      // Calculate discount
      double discount = 0;
      if (coupon.discountType == 'percentage') {
        discount = orderAmount * (coupon.discountValue / 100);
        if (coupon.maxDiscount != null && discount > coupon.maxDiscount!) {
          discount = coupon.maxDiscount!;
        }
      } else {
        discount = coupon.discountValue;
      }
      
      return {
        'valid': true,
        'discount': discount,
        'coupon': coupon,
      };
    } catch (e) {
      return {'valid': false, 'message': 'Invalid coupon code'};
    }
  }
}
