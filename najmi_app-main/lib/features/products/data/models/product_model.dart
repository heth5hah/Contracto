class ProductModel {
  final String id;
  final String productId;
  final String? brandId;
  final List<String> brandIds; // Support for multiple brands
  final String? category;
  final String? subcategory;
  final String productName;
  final String? description;
  final double? mrp;
  final String? hsnNumber;
  final double? gstPercent;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? discountPercent;
  final double? finalPrice;
  final List<String> photos;
  final String? unit;
  final List<QualityOption> qualityOptions;
  final bool isTopSeller;
  final bool isFeatured;
  final List<BulkDiscountRule> bulkDiscountRules;
  final double transportCharges;
  final String stockStatus;
  final int? stockQuantity;
  final bool isReturnable;

  ProductModel({
    required this.id,
    required this.productId,
    this.brandId,
    this.brandIds = const [],
    this.category,
    this.subcategory,
    required this.productName,
    this.description,
    this.mrp,
    this.hsnNumber,
    this.gstPercent,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.discountPercent,
    this.finalPrice,
    this.photos = const [],
    this.unit,
    this.qualityOptions = const [],
    this.isTopSeller = false,
    this.isFeatured = false,
    this.bulkDiscountRules = const [],
    this.transportCharges = 0.0,
    this.stockStatus = 'in_stock',
    this.stockQuantity,
    this.isReturnable = true,
  });

  // Helper method to check if product has multiple brands
  bool get hasMultipleBrands => brandIds.length > 1;

  // Helper method to get bulk discount for a quantity
  double? getBulkDiscountPercent(int quantity) {
    if (bulkDiscountRules.isEmpty) return null;
    
    // Sort rules by min quantity descending to get highest applicable discount
    final applicableRules = bulkDiscountRules
        .where((rule) => quantity >= rule.minQuantity)
        .toList()
      ..sort((a, b) => b.minQuantity.compareTo(a.minQuantity));
    
    return applicableRules.isNotEmpty ? applicableRules.first.discountPercent : null;
  }

  // Helper method to calculate price with bulk discount
  double? getPriceWithBulkDiscount(int quantity, double basePrice) {
    final discountPercent = getBulkDiscountPercent(quantity);
    if (discountPercent == null) return basePrice;
    
    return basePrice * (1 - discountPercent / 100);
  }

  // Check if product has bulk discounts
  bool get hasBulkDiscounts => bulkDiscountRules.isNotEmpty;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Handle brand_ids array from database
    List<String> brandIds = [];
    if (json['brand_ids'] != null) {
      if (json['brand_ids'] is List) {
        brandIds = (json['brand_ids'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      }
    }
    // Fallback: if brand_ids is empty but brand_id exists, use it
    if (brandIds.isEmpty && json['brand_id'] != null) {
      brandIds = [json['brand_id'] as String];
    }

    return ProductModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      brandId: json['brand_id'] as String?,
      brandIds: brandIds,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      productName: json['product_name'] as String,
      description: json['description'] as String?,
      mrp: json['mrp'] != null ? (json['mrp'] as num).toDouble() : null,
      hsnNumber: json['hsn_number'] as String?,
      gstPercent: json['gst_percent'] != null
          ? (json['gst_percent'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      discountPercent: json['discount_percent'] != null
          ? (json['discount_percent'] as num).toDouble()
          : null,
      finalPrice: json['final_price'] != null
          ? (json['final_price'] as num).toDouble()
          : null,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      unit: json['unit'] as String?,
      qualityOptions: (json['quality_options'] as List<dynamic>?)
              ?.map((e) => QualityOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isTopSeller: json['is_top_seller'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      bulkDiscountRules: (json['bulk_discount_rules'] as List<dynamic>?)
              ?.map((e) => BulkDiscountRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      transportCharges: json['transport_charges'] != null
          ? (json['transport_charges'] as num).toDouble()
          : 0.0,
      stockStatus: json['stock_status'] as String? ?? 'in_stock',
      stockQuantity: json['stock_quantity'] as int?,
      isReturnable: json['is_returnable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'brand_id': brandId,
      'brand_ids': brandIds,
      'category': category,
      'subcategory': subcategory,
      'product_name': productName,
      'description': description,
      'mrp': mrp,
      'hsn_number': hsnNumber,
      'gst_percent': gstPercent,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'discount_percent': discountPercent,
      'final_price': finalPrice,
      'photos': photos,
      'unit': unit,
      'quality_options': qualityOptions.map((e) => e.toJson()).toList(),
      'is_top_seller': isTopSeller,
      'is_featured': isFeatured,
      'bulk_discount_rules': bulkDiscountRules.map((e) => e.toJson()).toList(),
      'transport_charges': transportCharges,
      'stock_status': stockStatus,
      'stock_quantity': stockQuantity,
      'is_returnable': isReturnable,
    };
  }

  // Check if product has any pricing (single price or quality options)
  bool get hasPricing => mrp != null || qualityOptions.isNotEmpty;

  // Check if product has quality options
  bool get hasQualityOptions => qualityOptions.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class QualityOption {
  final String id;
  final String name;
  final double? mrp;
  final double? finalPrice;
  final double? discountPercent;

  QualityOption({
    required this.id,
    required this.name,
    this.mrp,
    this.finalPrice,
    this.discountPercent,
  });

  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      id: json['id'] as String? ??
          '${DateTime.now().millisecondsSinceEpoch}_${(json['option'] ?? json['name'])?.hashCode ?? 0}',
      name: (json['option'] ?? json['name']) as String? ?? '',
      mrp: json['mrp'] != null ? (json['mrp'] as num).toDouble() : null,
      finalPrice: json['final_price'] != null
          ? (json['final_price'] as num).toDouble()
          : null,
      discountPercent: json['discount'] != null
          ? (json['discount'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'option': name,
      'mrp': mrp,
      'final_price': finalPrice,
      'discount': discountPercent,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QualityOption && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class BulkDiscountRule {
  final int minQuantity;
  final double discountPercent;

  BulkDiscountRule({
    required this.minQuantity,
    required this.discountPercent,
  });

  factory BulkDiscountRule.fromJson(Map<String, dynamic> json) {
    return BulkDiscountRule(
      minQuantity: json['min_qty'] as int,
      discountPercent: (json['discount_percent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_qty': minQuantity,
      'discount_percent': discountPercent,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BulkDiscountRule &&
        other.minQuantity == minQuantity &&
        other.discountPercent == discountPercent;
  }

  @override
  int get hashCode => minQuantity.hashCode ^ discountPercent.hashCode;
}

