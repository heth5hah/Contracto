import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';

class ImageSlide {
  final String id;
  final String? title;
  final String? description;
  final String imageUrl;
  final String? linkUrl;
  final String? brandId;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ImageSlide({
    required this.id,
    this.title,
    this.description,
    required this.imageUrl,
    this.linkUrl,
    this.brandId,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ImageSlide.fromJson(Map<String, dynamic> json) {
    return ImageSlide(
      id: json['id'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String,
      linkUrl: json['link_url'] as String?,
      brandId: json['brand_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'brand_id': brandId,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ImageSlidesService {
  Future<List<ImageSlide>> getActiveSlides() async {
    try {
      final response = await SupabaseService.client
          .from('image_slides')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: false)
          .limit(5);

      return (response as List)
          .map((json) => ImageSlide.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching image slides: $e');
      // Return default slides if table doesn't exist
      return _getDefaultSlides();
    }
  }

  Future<BrandModel?> getBrandForSlide(String brandId) async {
    try {
      final response = await SupabaseService.client
          .from('brands')
          .select()
          .eq('id', brandId)
          .eq('is_active', true)
          .single();

      return BrandModel.fromJson(response);
    } catch (e) {
      print('Error fetching brand for slide: $e');
      return null;
    }
  }

  List<ImageSlide> _getDefaultSlides() {
    return [
      ImageSlide(
        id: 'default1',
        title: 'Welcome to Contracto',
        description: 'Your trusted partner for quality products',
        imageUrl: 'assets/images/contracto.png',
        sortOrder: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ImageSlide(
        id: 'default2',
        title: 'Quality Products',
        description: 'Browse our extensive collection',
        imageUrl: 'assets/images/contracto.png',
        sortOrder: 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ImageSlide(
        id: 'default3',
        title: 'Fast Delivery',
        description: 'Get your products delivered quickly',
        imageUrl: 'assets/images/contracto.png',
        sortOrder: 2,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}
