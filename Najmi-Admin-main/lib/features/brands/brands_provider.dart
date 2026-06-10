import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../categories/category_model.dart';

final brandsNotifierProvider = AsyncNotifierProvider<BrandsNotifier, List<Brand>>(BrandsNotifier.new);

class BrandsNotifier extends AsyncNotifier<List<Brand>> {
  @override
  Future<List<Brand>> build() async {
    print('BrandsNotifier: Starting to fetch brands...');
    try {
      final supabase = ref.watch(supabaseProvider);
      print('BrandsNotifier: Supabase client obtained');
      
      final response = await supabase
          .from('brands')
          .select('*')
          .order('name');
      
      print('BrandsNotifier: Response received: ${response.length} items');
      print('BrandsNotifier: Response data: $response');
      
      final brands = (response as List).map((json) {
        try {
          return Brand.fromJson(json);
        } catch (e) {
          print('BrandsNotifier: Error parsing brand: $e, JSON: $json');
          rethrow;
        }
      }).toList();
      
      print('BrandsNotifier: Successfully parsed ${brands.length} brands');
      return brands;
    } catch (e, stackTrace) {
      print('BrandsNotifier: Error in build(): $e');
      print('BrandsNotifier: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> addBrand(Brand brand) async {
    print('BrandsNotifier: addBrand called for: ${brand.name}');
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      // Build the insert data manually to ensure we only send what's needed
      final insertData = <String, dynamic>{
        'name': brand.name,
        'is_active': brand.isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Only add optional fields if they have values
      if (brand.description != null && brand.description!.isNotEmpty) {
        insertData['description'] = brand.description;
      }
      if (brand.logo != null && brand.logo!.isNotEmpty) {
        insertData['logo_url'] = brand.logo;
      }
      if (brand.catalogPdfUrl != null && brand.catalogPdfUrl!.isNotEmpty) {
        insertData['catalog_pdf_url'] = brand.catalogPdfUrl;
      }
      
      print('BrandsNotifier: Inserting brand with data: $insertData');
      
      final response = await supabase
          .from('brands')
          .insert(insertData)
          .select()
          .single();
      
      print('BrandsNotifier: Brand inserted successfully: $response');
      
      // Refresh the list
      ref.invalidateSelf();
    } catch (e, st) {
      print('BrandsNotifier: Error adding brand: $e');
      print('BrandsNotifier: Stack trace: $st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateBrand(Brand brand) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      final json = brand.toJson();
      json['updated_at'] = DateTime.now().toIso8601String();
      await supabase.from('brands').update(json).eq('id', brand.id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteBrand(String id) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('brands').delete().eq('id', id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> toggleBrandStatus(String id, bool isActive) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      await supabase
          .from('brands')
          .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

