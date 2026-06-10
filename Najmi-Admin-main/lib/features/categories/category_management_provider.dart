import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import '../../main.dart';

// Category model with new fields
class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String detailLevel; // 'short' or 'detailed'
  final Map<String, dynamic> rules;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.thumbnailUrl,
    this.detailLevel = 'short',
    this.rules = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      thumbnailUrl: json['thumbnail_url'],
      detailLevel: json['detail_level'] ?? 'short',
      rules: json['rules'] ?? {},
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'detail_level': detailLevel,
      'rules': rules,
      'is_active': isActive,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? thumbnailUrl,
    String? detailLevel,
    Map<String, dynamic>? rules,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      detailLevel: detailLevel ?? this.detailLevel,
      rules: rules ?? this.rules,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Provider for categories list
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    final response = await supabase
        .from('categories')
        .select('*')
        .order('name', ascending: true);
    
    return (response as List)
        .map((json) => CategoryModel.fromJson(json))
        .toList();
  } catch (e) {
    print('Error fetching categories: $e');
    return [];
  }
});

// Provider for category CRUD operations
final categoryManagementProvider = Provider((ref) => CategoryManagementService(ref));

class CategoryManagementService {
  final Ref ref;
  
  CategoryManagementService(this.ref);
  
  Future<void> createCategory(CategoryModel category) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase.from('categories').insert(category.toJson());
    ref.invalidate(categoriesProvider);
  }
  
  Future<void> updateCategory(String id, CategoryModel category) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase
        .from('categories')
        .update(category.toJson())
        .eq('id', id);
    
    ref.invalidate(categoriesProvider);
  }
  
  Future<void> deleteCategory(String id) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase
        .from('categories')
        .delete()
        .eq('id', id);
    
    ref.invalidate(categoriesProvider);
  }
  
  Future<String?> uploadThumbnail(String categoryId, List<int> fileBytes, String fileName) async {
    final supabase = ref.read(supabaseProvider);
    
    try {
      // Upload to Supabase Storage
      final path = 'category_thumbnails/$categoryId/$fileName';
      await supabase.storage
          .from('images')
          .uploadBinary(path, Uint8List.fromList(fileBytes));
      
      // Get public URL
      final url = supabase.storage
          .from('images')
          .getPublicUrl(path);
      
      return url;
    } catch (e) {
      print('Error uploading thumbnail: $e');
      return null;
    }
  }
}
