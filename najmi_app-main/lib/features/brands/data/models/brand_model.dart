class BrandModel {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? catalogUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BrandModel({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.catalogUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      catalogUrl: json['catalog_pdf_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'logo_url': logoUrl,
      'catalog_pdf_url': catalogUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrandModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
