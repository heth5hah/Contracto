import 'package:flutter/foundation.dart';

class CouponModel {
  final String id;
  final String code;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final double minOrderValue;
  final double? maxDiscount;
  final DateTime validFrom;
  final DateTime? validTo;
  final bool isActive;
  final int? usageLimit;
  final int timesUsed;
  final DateTime createdAt;
  final List<String> applicableUsers;
  final List<String> applicableProducts;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0,
    this.maxDiscount,
    required this.validFrom,
    this.validTo,
    this.isActive = true,
    this.usageLimit,
    this.timesUsed = 0,
    required this.createdAt,
    this.applicableUsers = const [],
    this.applicableProducts = const [],
  });

  // Check if coupon is currently valid
  bool get isValid {
    if (!isActive) {
      debugPrint('Coupon $code invalid: isActive=false');
      return false;
    }
    
    final now = DateTime.now().toUtc();
    final bufferedvalidFrom = validFrom.isUtc ? validFrom : validFrom.toUtc();
    
    debugPrint('Coupon $code check: now=$now, validFrom=$bufferedvalidFrom');
    
    if (now.add(const Duration(minutes: 1)).isBefore(bufferedvalidFrom)) {
      debugPrint('Coupon $code invalid: now is before validFrom');
      return false;
    }
    
    if (validTo != null) {
      final bufferedValidTo = validTo!.isUtc ? validTo! : validTo!.toUtc();
      debugPrint('Coupon $code expiry check: validTo=$bufferedValidTo');
      if (now.isAfter(bufferedValidTo)) {
        debugPrint('Coupon $code invalid: now is after validTo');
        return false;
      }
    }
    
    if (usageLimit != null && timesUsed >= usageLimit!) {
      debugPrint('Coupon $code invalid: usageLimit reached ($timesUsed/$usageLimit)');
      return false;
    }
    
    debugPrint('Coupon $code is VALID');
    return true;
  }

  // Calculate discount amount for given order value
  double calculateDiscount(double orderValue, {List<dynamic> cartItems = const []}) {
    if (!isValid || orderValue < minOrderValue) return 0;
    
    double applicableValue = orderValue;
    
    if (applicableProducts.isNotEmpty && cartItems.isNotEmpty) {
      applicableValue = 0;
      for (final item in cartItems) {
        if (applicableProducts.contains(item.product.id)) {
          applicableValue += item.totalPrice;
        }
      }
      if (applicableValue == 0) return 0;
    }

    double discount;
    if (discountType == 'percentage') {
      discount = applicableValue * (discountValue / 100);
      if (maxDiscount != null && discount > maxDiscount!) {
        discount = maxDiscount!;
      }
    } else {
      // Fixed discount
      discount = discountValue;
    }

    return discount;
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      code: json['code'] as String,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      minOrderValue: json['min_order_value'] != null
          ? (json['min_order_value'] as num).toDouble()
          : 0,
      maxDiscount: json['max_discount'] != null
          ? (json['max_discount'] as num).toDouble()
          : null,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validTo: json['valid_to'] != null
          ? DateTime.parse(json['valid_to'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      usageLimit: json['usage_limit'] as int?,
      timesUsed: json['times_used'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      applicableUsers: (json['applicable_users'] as List?)?.map((e) => e.toString()).toList() ?? [],
      applicableProducts: (json['applicable_products'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      'max_discount': maxDiscount,
      'valid_from': validFrom.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'is_active': isActive,
      'usage_limit': usageLimit,
      'times_used': timesUsed,
      'created_at': createdAt.toIso8601String(),
      'applicable_users': applicableUsers,
      'applicable_products': applicableProducts,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CouponModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
