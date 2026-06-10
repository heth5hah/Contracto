import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'category_model.dart';

final categoriesNotifierProvider = AsyncNotifierProvider<CategoriesNotifier, List<Category>>(CategoriesNotifier.new);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    print('CategoriesNotifier: Starting to fetch categories...');
    try {
      final supabase = ref.watch(supabaseProvider);
      print('CategoriesNotifier: Supabase client obtained');
      
      // Use the categories_with_counts view so we also get product_count and
      // subcategories for the admin table, similar to the web admin panel.
      final response = await supabase
          .from('categories_with_counts')
          .select('*')
          .order('name');
      
      print('CategoriesNotifier: Response received: ${response.length} items');
      
      final categories = (response as List).map((json) {
        try {
          return Category.fromJson(json);
        } catch (e) {
          print('CategoriesNotifier: Error parsing category: $e, JSON: $json');
          rethrow;
        }
      }).toList();
      
      print('CategoriesNotifier: Successfully parsed ${categories.length} categories');
      return categories;
    } catch (e, stackTrace) {
      print('CategoriesNotifier: Error in build(): $e');
      print('CategoriesNotifier: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> addCategory(Category category) async {
    print('CategoriesNotifier: addCategory called for: ${category.name}');
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      final insertData = <String, dynamic>{
        'name': category.name,
        'is_active': category.isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (category.description != null && category.description!.isNotEmpty) {
        insertData['description'] = category.description;
      }
      if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
        insertData['image_url'] = category.imageUrl;
      }
      
      print('CategoriesNotifier: Inserting category with data: $insertData');
      
      final response = await supabase
          .from('categories')
          .insert(insertData)
          .select()
          .single();
      
      print('CategoriesNotifier: Category inserted successfully: $response');
      
      ref.invalidateSelf();
    } catch (e, st) {
      print('CategoriesNotifier: Error adding category: $e');
      print('CategoriesNotifier: Stack trace: $st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      final updateData = <String, dynamic>{
        'name': category.name,
        'is_active': category.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (category.description != null) {
        updateData['description'] = category.description;
      }
      if (category.imageUrl != null) {
        updateData['image_url'] = category.imageUrl;
      }
      
      await supabase
          .from('categories')
          .update(updateData)
          .eq('id', category.id);
      
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('categories').delete().eq('id', id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> toggleCategoryStatus(String id, bool isActive) async {
    final supabase = ref.read(supabaseProvider);
    state = const AsyncValue.loading();
    try {
      await supabase
          .from('categories')
          .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

