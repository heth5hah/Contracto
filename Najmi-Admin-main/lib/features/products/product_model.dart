class Product {
  final String id;
  final String? productId;
  final String productName;
  final String? category;
  final String? subcategory;
  final String? unit;
  final String stockStatus;
  final int? stockQuantity;
  final String pricingType;
  final double? finalPrice;
  final double? mrp;
  final List<String>? photos;
  final List<String>? brandIds;
  final String? description;
  final String? hsnNumber;
  final double? gstPercent;
  final List<String> brandNames;
  final List<QualityOption> qualityOptions;
  final bool? isReturnable;

  Product({
    required this.id,
    this.productId,
    required this.productName,
    this.category,
    this.subcategory,
    this.unit,
    required this.stockStatus,
    this.stockQuantity,
    required this.pricingType,
    this.finalPrice,
    this.mrp,
    this.photos,
    this.brandIds,
    this.description,
    this.hsnNumber,
    this.gstPercent,
    this.brandNames = const [],
    this.qualityOptions = const [],
    this.isReturnable,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> parsedBrandNames = [];
    try {
      if (json['brands'] != null) {
        if (json['brands'] is List) {
          parsedBrandNames = (json['brands'] as List)
              .map((b) => b['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        } else if (json['brands'] is Map) {
          final name = json['brands']['name'] as String?;
          if (name != null) parsedBrandNames.add(name);
        }
      }
    } catch (e) {
      print('Error parsing brand names: $e');
    }

    return Product(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String? ?? 'Unknown',
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      unit: json['unit'] as String?,
      stockStatus: json['stock_status'] as String? ?? 'out_of_stock',
      stockQuantity: (json['stock_quantity'] as num?)?.toInt(),
      pricingType: json['pricing_type'] as String? ?? 'fixed_price',
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      mrp: (json['mrp'] as num?)?.toDouble(),
      photos: json['photos'] != null ? List<String>.from(json['photos']) : <String>[],
      brandIds: json['brand_ids'] != null ? List<String>.from(json['brand_ids']) : <String>[],
      description: json['description'] as String?,
      hsnNumber: json['hsn_number'] as String?,
      gstPercent: (json['gst_percent'] as num?)?.toDouble(),
      brandNames: parsedBrandNames,
      qualityOptions: json['quality_options'] != null
          ? (json['quality_options'] as List)
              .map((q) => QualityOption.fromJson(q as Map<String, dynamic>))
              .toList()
          : [],
      isReturnable: json['is_returnable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'product_id': productId,
      'product_name': productName,
      'category': category,
      'subcategory': subcategory,
      'unit': unit,
      'stock_status': stockStatus,
      'stock_quantity': stockQuantity,
      'pricing_type': pricingType,
      'final_price': finalPrice,
      'mrp': mrp,
      'photos': photos ?? [],
      'brand_ids': brandIds ?? [],
      'description': description,
      'hsn_number': hsnNumber,
      'gst_percent': gstPercent,
      'is_returnable': isReturnable ?? true,
      'quality_options': qualityOptions.map((q) => q.toJson()).toList(),
    };
  }

  Product copyWith({
    String? id,
    String? productId,
    String? productName,
    String? category,
    String? subcategory,
    String? unit,
    String? stockStatus,
    int? stockQuantity,
    String? pricingType,
    double? finalPrice,
    double? mrp,
    List<String>? photos,
    List<String>? brandIds,
    String? description,
    String? hsnNumber,
    double? gstPercent,
    List<String>? brandNames,
    List<QualityOption>? qualityOptions,
    bool? isReturnable,
  }) {
    return Product(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      unit: unit ?? this.unit,
      stockStatus: stockStatus ?? this.stockStatus,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      pricingType: pricingType ?? this.pricingType,
      finalPrice: finalPrice ?? this.finalPrice,
      mrp: mrp ?? this.mrp,
      photos: photos ?? this.photos,
      brandIds: brandIds ?? this.brandIds,
      description: description ?? this.description,
      hsnNumber: hsnNumber ?? this.hsnNumber,
      gstPercent: gstPercent ?? this.gstPercent,
      brandNames: brandNames ?? this.brandNames,
      qualityOptions: qualityOptions ?? this.qualityOptions,
      isReturnable: isReturnable ?? this.isReturnable,
    );
  }
}

class QualityOption {
  final String name;
  final double mrp;
  final double discount;
  final double finalPrice;

  QualityOption({
    required this.name,
    required this.mrp,
    required this.discount,
    required this.finalPrice,
  });

  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      name: (json['name'] ?? json['quality_option'] ?? json['option'] ?? '').toString().trim(),
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      finalPrice: (json['final_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mrp': mrp,
      'discount': discount,
      'final_price': finalPrice,
    };
  }
}
