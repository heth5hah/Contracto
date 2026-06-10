import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/categories/data/models/category_model.dart';

class CategoryService {
  /// Get all categories from categories table
  Future<List<CategoryModel>> getCategories() async {
    try {
      // Get categories from the dedicated categories table
      final categoriesResponse = await SupabaseService.client
          .from('categories')
          .select('*')
          .eq('is_active', true)
          .order('name'); // Use name instead of sort_order for now

      print('Categories response count: ${categoriesResponse.length}');

      final List<CategoryModel> categories = [];

      for (var categoryJson in categoriesResponse) {
        // Debug: Print raw category data
        print('Raw category data: $categoryJson');

        // Count products for this category
        final productCountResponse = await SupabaseService.client
            .from('products')
            .select('id')
            .eq('category', categoryJson['name'])
            .eq('is_active', true);

        final productCount = productCountResponse.length;

        // Create CategoryModel with product count
        final category = CategoryModel.fromJson({
          ...categoryJson,
          'product_count': productCount,
        });

        print(
            'Created category: ${category.name}, ImageURL: ${category.imageUrl}');
        categories.add(category);
      }

      return categories;
    } catch (e) {
      print('Error fetching categories from categories table: $e');

      // Fallback: Get categories from products table (backward compatibility)
      print('Falling back to products table for categories');
      return await _getCategoriesFromProducts();
    }
  }

  /// Fallback method: Get categories from products table (backward compatibility)
  Future<List<CategoryModel>> _getCategoriesFromProducts() async {
    try {
      print('Using fallback method: getting categories from products table');
      // Get distinct categories from products table
      final response = await SupabaseService.client
          .from('products')
          .select('category')
          .eq('is_active', true)
          .not('category', 'is', null);

      // Extract unique categories and count products for each
      final Map<String, int> categoryCount = {};
      for (var item in response) {
        final category = item['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      // Convert to CategoryModel list
      final List<CategoryModel> categories = [];
      for (var entry in categoryCount.entries) {
        categories.add(CategoryModel(
          id: entry.key.toLowerCase().replaceAll(' ', '_'),
          name: entry.key,
          description: null,
          imageUrl: null,
          isActive: true,
          productCount: entry.value,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // Sort by name
      categories.sort((a, b) => a.name.compareTo(b.name));
      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  /// Get category by ID (name)
  Future<CategoryModel?> getCategoryById(String id) async {
    try {
      // Convert ID back to category name
      final categoryName = id.replaceAll('_', ' ').toUpperCase();

      final response = await SupabaseService.client
          .from('products')
          .select('category')
          .eq('category', categoryName)
          .eq('is_active', true);

      if (response.isEmpty) return null;

      return CategoryModel(
        id: id,
        name: categoryName,
        description: null,
        imageUrl: null,
        isActive: true,
        productCount: response.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error fetching category by ID: $e');
      return null;
    }
  }

  /// Create a new category (not applicable with current structure)
  Future<CategoryModel?> createCategory({
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    // Since categories are derived from products, we can't create them directly
    // This would require adding products with this category
    print(
        'Cannot create categories directly. Add products with this category instead.');
    return null;
  }

  /// Update category (not applicable with current structure)
  Future<CategoryModel?> updateCategory({
    required String id,
    String? name,
    String? description,
    String? imageUrl,
    bool? isActive,
  }) async {
    // Since categories are derived from products, we can't update them directly
    print(
        'Cannot update categories directly. Update products with this category instead.');
    return null;
  }

  /// Delete category (not applicable with current structure)
  Future<bool> deleteCategory(String id) async {
    // Since categories are derived from products, we can't delete them directly
    print(
        'Cannot delete categories directly. Remove or update products with this category instead.');
    return false;
  }

  /// Get products by category
  Future<List<Map<String, dynamic>>> getProductsByCategory(
      String categoryId) async {
    try {
      // Convert category ID back to category name
      final categoryName = categoryId.replaceAll('_', ' ').toUpperCase();

      final response = await SupabaseService.client
          .from('products')
          .select('''
            *,
            brand:brands(name, logo_url)
          ''')
          .eq('category', categoryName)
          .eq('is_active', true)
          .order('product_name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching products by category: $e');
      return [];
    }
  }

  /// Get products by category name (helper method)
  Future<List<Map<String, dynamic>>> getProductsByCategoryName(
      String categoryName) async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select('''
            *,
            brand:brands(name, logo_url)
          ''')
          .eq('category', categoryName)
          .eq('is_active', true)
          .order('product_name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching products by category name: $e');
      return [];
    }
  }

  /// Get category hierarchy (parent categories with their children)
  Future<List<CategoryModel>> getCategoryHierarchy() async {
    try {
      // Get all categories
      final allCategories = await getCategories();
      
      // Separate parent and child categories
      final parentCategories = allCategories.where((c) => c.isParent).toList();
      final childCategories = allCategories.where((c) => c.isChild).toList();
      
      // Build hierarchy by attaching children to parents
      final hierarchicalCategories = <CategoryModel>[];
      
      for (final parent in parentCategories) {
        final children = childCategories
            .where((child) => child.parentCategoryId == parent.id)
            .toList();
        
        hierarchicalCategories.add(parent.copyWith(children: children));
      }
      
      return hierarchicalCategories;
    } catch (e) {
      print('Error fetching category hierarchy: $e');
      return [];
    }
  }

  /// Get child categories for a parent category
  Future<List<CategoryModel>> getChildCategories(String parentId) async {
    try {
      final response = await SupabaseService.client
          .from('categories')
          .select('*')
          .eq('parent_category_id', parentId)
          .eq('is_active', true)
          .order('name');

      final List<CategoryModel> categories = [];
      
      for (var categoryJson in response) {
        // Count products for this category
        final productCountResponse = await SupabaseService.client
            .from('products')
            .select('id')
            .eq('category', categoryJson['name'])
            .eq('is_active', true);

        final productCount = productCountResponse.length;

        categories.add(CategoryModel.fromJson({
          ...categoryJson,
          'product_count': productCount,
        }));
      }

      return categories;
    } catch (e) {
      print('Error fetching child categories: $e');
      return [];
    }
  }

  /// Get parent category for a child category
  Future<CategoryModel?> getParentCategory(String childId) async {
    try {
      // First get the child category to find its parent ID
      final childResponse = await SupabaseService.client
          .from('categories')
          .select('parent_category_id')
          .eq('id', childId)
          .maybeSingle();

      if (childResponse == null || childResponse['parent_category_id'] == null) {
        return null;
      }

      final parentId = childResponse['parent_category_id'] as String;

      // Get the parent category
      final parentResponse = await SupabaseService.client
          .from('categories')
          .select('*')
          .eq('id', parentId)
          .single();

      // Count products for parent category
      final productCountResponse = await SupabaseService.client
          .from('products')
          .select('id')
          .eq('category', parentResponse['name'])
          .eq('is_active', true);

      return CategoryModel.fromJson({
        ...parentResponse,
        'product_count': productCountResponse.length,
      });
    } catch (e) {
      print('Error fetching parent category: $e');
      return null;
    }
  }
}
