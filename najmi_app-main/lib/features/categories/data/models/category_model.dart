class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? iconName; // Fallback icon when no image
  final int sortOrder;
  final bool isActive;
  final int productCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentCategoryId;
  final List<CategoryModel> children;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.iconName,
    this.sortOrder = 0,
    required this.isActive,
    required this.productCount,
    required this.createdAt,
    required this.updatedAt,
    this.parentCategoryId,
    this.children = const [],
  });

  // Helper methods for hierarchy
  bool get isParent => parentCategoryId == null;
  bool get hasChildren => children.isNotEmpty;
  bool get isChild => parentCategoryId != null;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      iconName: json['icon_name'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      productCount: json['product_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      parentCategoryId: json['parent_category_id'] as String?,
      children: [], // Children loaded separately if needed
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'icon_name': iconName,
      'sort_order': sortOrder,
      'is_active': isActive,
      'product_count': productCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'parent_category_id': parentCategoryId,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? iconName,
    int? sortOrder,
    bool? isActive,
    int? productCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentCategoryId,
    List<CategoryModel>? children,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      children: children ?? this.children,
    );
  }

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, description: $description, imageUrl: $imageUrl, isActive: $isActive, productCount: $productCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.imageUrl == imageUrl &&
        other.isActive == isActive &&
        other.productCount == productCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        imageUrl.hashCode ^
        isActive.hashCode ^
        productCount.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
