import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';

class BrandService {
  Future<List<BrandModel>> getBrands({bool activeOnly = true}) async {
    final query = SupabaseService.client.from('brands').select();

    if (activeOnly) {
      query.eq('is_active', true);
    }

    final response = await query.order('name');
    return (response as List).map((json) => BrandModel.fromJson(json)).toList();
  }

  Future<BrandModel> addBrand(BrandModel brand) async {
    final response = await SupabaseService.client
        .from('brands')
        .insert(brand.toJson())
        .select()
        .single();

    return BrandModel.fromJson(response);
  }

  Future<BrandModel> updateBrand(BrandModel brand) async {
    final response = await SupabaseService.client
        .from('brands')
        .update(brand.toJson())
        .eq('id', brand.id)
        .select()
        .single();

    return BrandModel.fromJson(response);
  }

  Future<void> deleteBrand(String id) async {
    await SupabaseService.client.from('brands').delete().eq('id', id);
  }

  Future<void> toggleBrandStatus(String id, bool isActive) async {
    await SupabaseService.client
        .from('brands')
        .update({'is_active': isActive}).eq('id', id);
  }

  Future<List<BrandModel>> searchBrands(String query) async {
    try {
      // Normalize the query for better search
      final normalizedQuery = query.trim().toLowerCase();

      // Split query into words for more flexible matching
      final queryWords =
          normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();

      if (queryWords.isEmpty) return [];

      // Build search conditions for each word
      final searchConditions = <String>[];
      for (final word in queryWords) {
        searchConditions.add('name.ilike.%$word%');
        searchConditions.add('description.ilike.%$word%');
      }

      final response = await SupabaseService.client
          .from('brands')
          .select()
          .eq('is_active', true)
          .or(searchConditions.join(','))
          .order('name');

      final brands =
          (response as List).map((json) => BrandModel.fromJson(json)).toList();

      // Sort by relevance (exact matches first, then partial matches)
      brands.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();

        // Exact match gets highest priority
        if (aName == normalizedQuery) return -1;
        if (bName == normalizedQuery) return 1;

        // Starts with query gets second priority
        if (aName.startsWith(normalizedQuery)) return -1;
        if (bName.startsWith(normalizedQuery)) return 1;

        // Contains query gets third priority
        if (aName.contains(normalizedQuery)) return -1;
        if (bName.contains(normalizedQuery)) return 1;

        // Alphabetical order for remaining items
        return aName.compareTo(bName);
      });

      return brands;
    } catch (e) {
      print('Error searching brands: $e');
      return [];
    }
  }

  Future<List<BrandModel>> getBrandsByIds(List<String> brandIds) async {
    if (brandIds.isEmpty) return [];

    final response = await SupabaseService.client
        .from('brands')
        .select()
        .inFilter('id', brandIds)
        .eq('is_active', true)
        .order('name');

    return (response as List).map((json) => BrandModel.fromJson(json)).toList();
  }

  Future<BrandModel?> getBrandById(String brandId) async {
    try {
      final response = await SupabaseService.client
          .from('brands')
          .select()
          .eq('id', brandId)
          .single();

      return BrandModel.fromJson(response);
    } catch (e) {
      print('Error fetching brand by ID: $e');
      return null;
    }
  }

  Future<List<BrandModel>> getFeaturedBrands() async {
    try {
      final response =
          await SupabaseService.client.from('featured_brands').select('''
            id,
            sort_order,
            brands!inner(
              id,
              name,
              description,
              logo_url,
              is_active,
              created_at,
              updated_at
            )
          ''').eq('is_active', true).order('sort_order').limit(20);

      final List<BrandModel> featuredBrands = [];
      for (final item in response) {
        if (item['brands'] != null) {
          featuredBrands.add(BrandModel.fromJson(item['brands']));
        }
      }

      return featuredBrands;
    } catch (e) {
      print('Error fetching featured brands: $e');
      // Fallback to regular brands if featured table doesn't exist
      return getBrands(activeOnly: true);
    }
  }
}
