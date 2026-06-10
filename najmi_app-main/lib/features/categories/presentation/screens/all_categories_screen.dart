import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
import 'package:contracto_app/features/categories/data/models/category_model.dart';
import 'package:contracto_app/features/categories/data/services/category_service.dart';


class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final CategoryService _categoryService = CategoryService();
  List<CategoryModel> _categories = [];
  List<CategoryModel> _filteredCategories = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = List.from(_categories);
      } else {
        _filteredCategories = _categories
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      setState(() => _isLoading = true);
      final categories = await _categoryService.getCategories();
      setState(() {
        _categories = categories;
        _filteredCategories = List.from(categories);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _navigateToCategoryProducts(CategoryModel category) {
    // Pop back to home and pass the category name so home can select that tab
    Navigator.pop(context, category.name);
  }

  String _toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Map category names to 3D asset paths
  String? _get3DCategoryAsset(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('tool')) return 'assets/images/cat_tools_3d.png';
    if (name.contains('pump')) return 'assets/images/cat_pump_3d.png';
    if (name.contains('plumbing')) return 'assets/images/cat_plumbing_3d.png';
    if (name.contains('electrical')) {
      return 'assets/images/cat_electrical_3d.png';
    }
    if (name.contains('cable')) return 'assets/images/cat_cables_3d.png';
    if (name.contains('structural') || name.contains('m.s')) {
      return 'assets/images/cat_structural_3d.png';
    }
    if (name.contains('waterproofing')) {
      return 'assets/images/cat_waterproofing_3d.png';
    }
    if (name.contains('switch')) return 'assets/images/cat_switches_3d.png';
    if (name.contains('lighting') || name.contains('light')) {
      return 'assets/images/cat_lighting_3d.png';
    }
    if (name.contains('hardware')) return 'assets/images/cat_hardware_3d.png';
    if (name.contains('bath') || name.contains('faucet')) {
      return 'assets/images/cat_bath_3d.png';
    }
    if (name.contains('building') || name.contains('material')) {
      return 'assets/images/cat_building_3d.png';
    }
    if (name.contains('dustbin') || name.contains('bin')) {
      return 'assets/images/cat_dustbin_3d.png';
    }
    return null;
  }

  Widget _build3DIcon(CategoryModel category) {
    final asset = _get3DCategoryAsset(category.name);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackImage(category),
      );
    }
    return _buildFallbackImage(category);
  }

  Widget _buildFallbackImage(CategoryModel category) {
    if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
      return CustomNetworkImage(
        imageUrl: category.imageUrl!,
        fit: BoxFit.contain,
        width: double.infinity,
        errorWidget: const Icon(
          Icons.category_rounded,
          size: 36,
          color: Color(0xFF94A3B8),
        ),
      );
    }
    return const Icon(
      Icons.category_rounded,
      size: 36,
      color: Color(0xFF94A3B8),
    );
  }

  Widget _buildCategoryCard(CategoryModel category, int index) {
    return GestureDetector(
      onTap: () => _navigateToCategoryProducts(category),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area — 3D icon, no border
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _build3DIcon(category),
                ),
              ),
            ),
            // Category Name + Count
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _toTitleCase(category.name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${category.productCount} products',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        title: const Text(
          'All Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Category count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text(
                  '${_filteredCategories.length} categories',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Category grid
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : _filteredCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _searchController.text.isNotEmpty
                                    ? Icons.search_off_rounded
                                    : Icons.category_outlined,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Matching Categories'
                                  : 'No Categories Available',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Categories will appear here once added',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          return _buildCategoryCard(
                            _filteredCategories[index],
                            index,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[200]!,
          highlightColor: Colors.grey[50]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      },
    );
  }
}
