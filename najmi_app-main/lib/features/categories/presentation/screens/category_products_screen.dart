import 'package:flutter/material.dart';
import 'package:contracto_app/features/categories/data/models/category_model.dart';
import 'package:contracto_app/features/categories/data/services/category_service.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:contracto_app/shared/widgets/cart_notification.dart';
import 'package:contracto_app/shared/widgets/standard_product_card.dart';
import 'package:provider/provider.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';
import 'package:contracto_app/core/services/realtime_sync_service.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

class CategoryProductsScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryProductsScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final CategoryService _categoryService = CategoryService();
  final _realtimeSync = RealtimeSyncService();
  StreamSubscription? _productsSubscription;
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _sortBy = 'default';

  // Pastel colors for product cards
  static const _pastelColors = [
    Color(0xFFFFFACD),
    Color(0xFFFFCDD2),
    Color(0xFFE6E6FA),
    Color(0xFFD4F4DD),
    Color(0xFFFFE0B2),
    Color(0xFFB3E5FC),
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _setupRealtimeSync();
    _searchController.addListener(_onSearch);
  }

  void _setupRealtimeSync() {
    _productsSubscription = _realtimeSync.productsStream.listen(
      (productsJson) {
        if (mounted) _loadProducts();
      },
      onError: (error, stackTrace) {
        print('Error in real-time stream (CategoryProductsScreen): $error');
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredProducts = _products.where((p) {
        if (query.isEmpty) return true;
        return p.productName.toLowerCase().contains(query);
      }).toList();

      // Apply sort
      switch (_sortBy) {
        case 'price_low':
          _filteredProducts.sort((a, b) =>
              (a.finalPrice ?? double.infinity)
                  .compareTo(b.finalPrice ?? double.infinity));
          break;
        case 'price_high':
          _filteredProducts.sort((a, b) =>
              (b.finalPrice ?? 0).compareTo(a.finalPrice ?? 0));
          break;
        case 'name':
          _filteredProducts.sort(
              (a, b) => a.productName.compareTo(b.productName));
          break;
      }
    });
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);
      final productsData = await _categoryService
          .getProductsByCategoryName(widget.category.name);

      final products =
          productsData.map((data) => ProductModel.fromJson(data)).toList();

      setState(() {
        _products = products;
        _filteredProducts = List.from(products);
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _navigateToProductDetails(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, int index) {
    double? discountPercentage;
    if (product.mrp != null &&
        product.finalPrice != null &&
        product.mrp! > product.finalPrice! &&
        product.finalPrice! > 0) {
      discountPercentage =
          ((product.mrp! - product.finalPrice!) / product.mrp!) * 100;
    }

    return StandardProductCard(
      product: product,
      imageBackgroundColor: _pastelColors[index % _pastelColors.length],
      onTap: () => _navigateToProductDetails(product),
      onAddToCart: () {
        final cartService = Provider.of<CartService>(context, listen: false);

        if (product.stockQuantity != null) {
          final currentQty = cartService.cartItems
              .where((i) => i.product.id == product.id)
              .fold(0.0, (sum, i) => sum + i.quantity);
          if (currentQty + 1 > product.stockQuantity!) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Only ${product.stockQuantity} items available in stock'),
                backgroundColor: const Color(0xFFF59E0B),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
        }

        cartService.addToCart(product, 1);
        CartNotification.show(
          context,
          productName: product.productName,
          onViewCart: () {
            Navigator.of(context, rootNavigator: true)
                .pushNamed('/main', arguments: 2);
          },
        );
      },
      onRequestQuote: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.productName} added to quote request'),
            backgroundColor: const Color(0xFFFF6B35),
          ),
        );
      },
      showDiscount: discountPercentage != null && discountPercentage > 0,
      discountPercentage: discountPercentage,
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            _sortOption('Default', 'default'),
            _sortOption('Price: Low to High', 'price_low'),
            _sortOption('Price: High to Low', 'price_high'),
            _sortOption('Name: A to Z', 'name'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      onTap: () {
        setState(() => _sortBy = value);
        _applyFilters();
        Navigator.pop(context);
      },
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[400],
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          slivers: [
            // Modern collapsible app bar
            SliverAppBar(
              expandedHeight: 100,
              floating: true,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: _showSortSheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Sort',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                title: Text(
                  widget.category.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),

            // Search bar + count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      hintText: 'Search in ${widget.category.name}...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[400], size: 18),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            // Product count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '${_filteredProducts.length} products',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),

            // Product grid
            _isLoading
                ? SliverToBoxAdapter(child: _buildShimmerGrid())
                : _filteredProducts.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  _searchController.text.isNotEmpty
                                      ? Icons.search_off_rounded
                                      : Icons.inventory_2_outlined,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No matching products'
                                    : 'No products available',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Products will appear here once added',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.70,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildProductCard(
                                  _filteredProducts[index], index);
                            },
                            childCount: _filteredProducts.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
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
      ),
    );
  }
}
