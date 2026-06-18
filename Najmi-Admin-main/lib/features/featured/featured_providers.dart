import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../products/product_model.dart';
import '../categories/category_model.dart';

/// Single featured product entry joined with full product details.
class FeaturedProductEntry {
  final String id;
  final Product product;
  final int sortOrder;
  final bool isActive;

  FeaturedProductEntry({
    required this.id,
    required this.product,
    required this.sortOrder,
    required this.isActive,
  });
}

/// Single featured brand entry joined with full brand details.
class FeaturedBrandEntry {
  final String id;
  final Brand brand;
  final int sortOrder;
  final bool isActive;

  FeaturedBrandEntry({
    required this.id,
    required this.brand,
    required this.sortOrder,
    required this.isActive,
  });
}

/// Image slide shown in the user app home screen.
class ImageSlide {
  final String id;
  final String? title;
  final String? description;
  final String imageUrl;
  final String? linkUrl;
  final String? brandId;
  final int sortOrder;
  final bool isActive;

  ImageSlide({
    required this.id,
    this.title,
    this.description,
    required this.imageUrl,
    this.linkUrl,
    this.brandId,
    required this.sortOrder,
    required this.isActive,
  });

  factory ImageSlide.fromJson(Map<String, dynamic> json) {
    return ImageSlide(
      id: json['id'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String,
      linkUrl: json['link_url'] as String?,
      brandId: json['brand_id'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Provider for featured products list.
final featuredProductsProvider =
    AsyncNotifierProvider<FeaturedProductsNotifier, List<FeaturedProductEntry>>(
        FeaturedProductsNotifier.new);

class FeaturedProductsNotifier extends AsyncNotifier<List<FeaturedProductEntry>> {
  @override
  Future<List<FeaturedProductEntry>> build() async {
    final supabase = ref.watch(supabaseProvider);

    final response = await supabase
        .from('featured_products')
        .select('''
          id,
          sort_order,
          is_active,
          products!inner(*, brands(name))
        ''')
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final rows = response as List;
    final items = <FeaturedProductEntry>[];

    for (final row in rows) {
      try {
        final productJson = Map<String, dynamic>.from(row['products'] as Map);
        final product = Product.fromJson(productJson);
        items.add(
          FeaturedProductEntry(
            id: row['id'] as String,
            product: product,
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            isActive: row['is_active'] as bool? ?? true,
          ),
        );
      } catch (_) {
        // Skip malformed rows but keep others.
        continue;
      }
    }

    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<void> addFeaturedProduct(Product product) async {
    final supabase = ref.read(supabaseProvider);

    // Pick next sort order based on existing state when possible.
    final current = state.valueOrNull ?? <FeaturedProductEntry>[];
    final maxSort = current.isEmpty
        ? 0
        : current.map((e) => e.sortOrder).reduce(math.max);
    final nextSort = maxSort + 10;

    await supabase.from('featured_products').insert({
      'product_id': product.id,
      'sort_order': nextSort,
      'is_active': true,
    });

    ref.invalidateSelf();
  }

  Future<void> updateFeaturedProduct(String id,
      {int? sortOrder, bool? isActive}) async {
    final supabase = ref.read(supabaseProvider);

    final update = <String, dynamic>{};
    if (sortOrder != null) update['sort_order'] = sortOrder;
    if (isActive != null) update['is_active'] = isActive;
    if (update.isEmpty) return;

    await supabase.from('featured_products').update(update).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> removeFeaturedProduct(String id) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('featured_products').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

/// Provider for featured brands list.
final featuredBrandsProvider =
    AsyncNotifierProvider<FeaturedBrandsNotifier, List<FeaturedBrandEntry>>(
        FeaturedBrandsNotifier.new);

class FeaturedBrandsNotifier extends AsyncNotifier<List<FeaturedBrandEntry>> {
  @override
  Future<List<FeaturedBrandEntry>> build() async {
    final supabase = ref.watch(supabaseProvider);

    final response = await supabase
        .from('featured_brands')
        .select('''
          id,
          sort_order,
          is_active,
          brands!inner(*)
        ''')
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final rows = response as List;
    final items = <FeaturedBrandEntry>[];

    for (final row in rows) {
      try {
        final brandJson = Map<String, dynamic>.from(row['brands'] as Map);
        final brand = Brand.fromJson(brandJson);
        items.add(
          FeaturedBrandEntry(
            id: row['id'] as String,
            brand: brand,
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            isActive: row['is_active'] as bool? ?? true,
          ),
        );
      } catch (_) {
        // Skip malformed rows but keep others.
        continue;
      }
    }

    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<void> addFeaturedBrand(Brand brand) async {
    final supabase = ref.read(supabaseProvider);

    final current = state.valueOrNull ?? <FeaturedBrandEntry>[];
    final maxSort =
        current.isEmpty ? 0 : current.map((e) => e.sortOrder).reduce(math.max);
    final nextSort = maxSort + 10;

    await supabase.from('featured_brands').insert({
      'brand_id': brand.id,
      'sort_order': nextSort,
      'is_active': true,
    });

    ref.invalidateSelf();
  }

  Future<void> updateFeaturedBrand(String id,
      {int? sortOrder, bool? isActive}) async {
    final supabase = ref.read(supabaseProvider);

    final update = <String, dynamic>{};
    if (sortOrder != null) update['sort_order'] = sortOrder;
    if (isActive != null) update['is_active'] = isActive;
    if (update.isEmpty) return;

    await supabase.from('featured_brands').update(update).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> removeFeaturedBrand(String id) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('featured_brands').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

/// Provider for image slides.
final imageSlidesProvider =
    AsyncNotifierProvider<ImageSlidesNotifier, List<ImageSlide>>(
        ImageSlidesNotifier.new);

class ImageSlidesNotifier extends AsyncNotifier<List<ImageSlide>> {
  @override
  Future<List<ImageSlide>> build() async {
    final supabase = ref.watch(supabaseProvider);
    final response = await supabase
        .from('image_slides')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final rows = response as List;
    return rows
        .map((row) => ImageSlide.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> addSlide({
    String? title,
    String? description,
    required String imageUrl,
    String? linkUrl,
    String? brandId,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final supabase = ref.read(supabaseProvider);

    await supabase.from('image_slides').insert({
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'brand_id': brandId,
      'sort_order': sortOrder,
      'is_active': isActive,
    });

    ref.invalidateSelf();
  }

  Future<void> updateSlide(String id,
      {String? title,
      String? description,
      String? imageUrl,
      String? linkUrl,
      String? brandId,
      bool updateBrandId = false,
      int? sortOrder,
      bool? isActive}) async {
    final supabase = ref.read(supabaseProvider);

    final update = <String, dynamic>{};
    if (title != null) update['title'] = title.trim().isEmpty ? null : title.trim();
    if (description != null) update['description'] = description.trim().isEmpty ? null : description.trim();
    if (imageUrl != null) update['image_url'] = imageUrl;
    if (linkUrl != null) update['link_url'] = linkUrl.trim().isEmpty ? null : linkUrl.trim();
    if (updateBrandId) update['brand_id'] = brandId;
    if (sortOrder != null) update['sort_order'] = sortOrder;
    if (isActive != null) update['is_active'] = isActive;
    if (update.isEmpty) return;

    await supabase.from('image_slides').update(update).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteSlide(String id) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('image_slides').delete().eq('id', id);
    ref.invalidateSelf();
  }
}
