class Category {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Additional admin-only fields coming from the categories_with_counts view
  /// in Supabase. These are optional and default to sensible values when
  /// loading directly from the base categories table.
  final int productCount;
  final List<String> subcategories;

  /// Default GST percentage applied to products in this category.
  /// Can be overridden per-product via products.gst_percent.
  final double? gstPercent;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.productCount = 0,
    this.subcategories = const [],
    this.gstPercent,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    try {
      DateTime parseDate(dynamic dateValue) {
        if (dateValue == null) return DateTime.now();
        if (dateValue is String) {
          try {
            return DateTime.parse(dateValue);
          } catch (e) {
            print('Error parsing date: $dateValue, error: $e');
            return DateTime.now();
          }
        }
        return DateTime.now();
      }

      // Handle optional fields from categories_with_counts view
      int parseProductCount(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value.toString()) ?? 0;
      }

      List<String> parseSubcategories(dynamic value) {
        if (value == null) return const [];
        if (value is List) {
          return value
              .where((e) => e != null)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return const [];
      }

      return Category(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown',
        description: json['description']?.toString(),
        imageUrl: json['image_url']?.toString(),
        isActive: json['is_active'] is bool
            ? json['is_active'] as bool
            : (json['is_active'] == true || json['is_active'] == 'true'),
        createdAt: parseDate(json['created_at']),
        updatedAt:
            json['updated_at'] != null ? parseDate(json['updated_at']) : null,
        productCount: parseProductCount(json['product_count']),
        subcategories: parseSubcategories(json['subcategories']),
        gstPercent: (json['gst_percent'] as num?)?.toDouble(),
      );
    } catch (e) {
      print('Error parsing Category from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      if (gstPercent != null) 'gst_percent': gstPercent,
      // product_count & subcategories come from the view and are derived from
      // products; they are not written back to the base categories table.
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? productCount,
    List<String>? subcategories,
    double? gstPercent,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productCount: productCount ?? this.productCount,
      subcategories: subcategories ?? this.subcategories,
      gstPercent: gstPercent ?? this.gstPercent,
    );
  }
}

class Brand {
  final String id;
  final String name;
  final String? logo;
  final String? description;
  final bool isActive;
  final String? catalogPdfUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Brand({
    required this.id,
    required this.name,
    this.logo,
    this.description,
    this.isActive = true,
    this.catalogPdfUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    try {
      // Handle different date formats
      DateTime parseDate(dynamic dateValue) {
        if (dateValue == null) return DateTime.now();
        if (dateValue is String) {
          try {
            return DateTime.parse(dateValue);
          } catch (e) {
            print('Error parsing date: $dateValue, error: $e');
            return DateTime.now();
          }
        }
        return DateTime.now();
      }

      return Brand(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown',
        logo: json['logo_url']?.toString(),
        description: json['description']?.toString(),
        isActive: json['is_active'] is bool ? json['is_active'] as bool : (json['is_active'] == true || json['is_active'] == 'true'),
        catalogPdfUrl: json['catalog_pdf_url']?.toString(),
        createdAt: parseDate(json['created_at']),
        updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
      );
    } catch (e) {
      print('Error parsing Brand from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logo,
      'description': description,
      'is_active': isActive,
      'catalog_pdf_url': catalogPdfUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Brand copyWith({
    String? id,
    String? name,
    String? logo,
    String? description,
    bool? isActive,
    String? catalogPdfUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Brand(
      id: id ?? this.id,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      catalogPdfUrl: catalogPdfUrl ?? this.catalogPdfUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
