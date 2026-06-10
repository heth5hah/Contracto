import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'category_model.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  print('Fetching categories...');
  try {
    final supabase = ref.watch(supabaseProvider);
    final response = await supabase.from('categories').select('*').order('name');
    print('Categories fetched: ${(response as List).length} items');
    return (response as List).map((json) => Category.fromJson(json)).toList();
  } catch (e) {
    print('Error fetching categories: $e');
    rethrow;
  }
});

final brandsProvider = FutureProvider<List<Brand>>((ref) async {
  print('Fetching brands...');
  try {
    final supabase = ref.watch(supabaseProvider);
    // Fetch all brands (including inactive) for admin panel
    final response = await supabase
        .from('brands')
        .select('*')
        .order('name');
    print('Brands fetched: ${(response as List).length} items');
    return (response as List).map((json) => Brand.fromJson(json)).toList();
  } catch (e) {
    print('Error fetching brands: $e');
    rethrow;
  }
});
