import 'package:flutter/material.dart';
import 'dart:async';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/brands/data/services/brand_service.dart';
import 'package:contracto_app/features/brands/presentation/screens/brand_products_screen.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/features/products/data/services/product_service.dart';
import 'package:contracto_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:contracto_app/features/products/presentation/screens/product_brands_screen.dart';
import 'package:contracto_app/features/products/presentation/screens/product_enquiry_screen.dart';
import 'package:shimmer/shimmer.dart';

class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String _selectedCategory = 'Sinks';
  int _selectedFilterIndex = 0;
  bool _isLoggedIn = false;
  List<BrandModel> _brands = [];
  List<ProductModel> _products = [];
  List<ProductModel> _searchResults = [];
  List<BrandModel> _searchBrands = [];
  bool _loadingBrands = true;
  bool _loadingProducts = true;
  bool _isSearching = false;
  bool _showSearchResults = false;
  String _currentSearchQuery = '';

  final _brandService = BrandService();
  final _productService = ProductService();

  final List<String> _filterOptions = [
    'Sort By',
    'Filters',
    '24 Hrs Delivery',
    'Brands',
  ];

  final List<String> _categories = [
    'Sinks',
    'Showers',
    'Faucets',
    'Tiles',
    'Paints',
    'Tools',
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _loadBrands();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _checkAuthStatus() {
    final user = SupabaseService.instance.currentUser;
    setState(() {
      _isLoggedIn = user != null;
    });
  }

  Future<void> _loadBrands() async {
    try {
      final brands = await _brandService.getBrands(activeOnly: true);
      setState(() {
        _brands = brands.take(8).toList();
        _loadingBrands = false;
      });
    } catch (e) {
      setState(() => _loadingBrands = false);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.getProducts();
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (e) {
      setState(() => _loadingProducts = false);
    }
  }

  void _onScroll() {
    // Handle scroll behavior if needed
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchBrands = [];
        _isSearching = false;
        _showSearchResults = false;
        _currentSearchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentSearchQuery = query;
      _showSearchResults = true;
    });

    try {
      // Search products and brands in parallel
      final results = await Future.wait([
        _productService.searchProductsWithBrands(query),
        _brandService.searchBrands(query),
      ]);

      final products = results[0] as List<ProductModel>;
      final brands = results[1] as List<BrandModel>;

      setState(() {
        _searchResults = products;
        _searchBrands = brands;
        _isSearching = false;
      });

      if (products.isEmpty && brands.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No results found for "$query"'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // Debouncer for search
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        _clearSearch();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _searchBrands = [];
      _showSearchResults = false;
      _currentSearchQuery = '';
      _isSearching = false;
    });
  }

  void _onBrandTap(BrandModel brand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandProductsScreen(brand: brand),
      ),
    );
  }

  void _onProductTap(ProductModel product) {
    // Show options to view product details or all brands for this product
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
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
              title: const Text('View Product Details'),
              subtitle: Text('See full details of ${product.productName}'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProductDetailsScreen(product: product),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.business, color: Color(0xFF2563EB)),
              title: const Text('View All Brands'),
              subtitle:
                  Text('See all brands that carry ${product.productName}'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProductBrandsScreen(productName: product.productName),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),

              // Filter Options
              if (!_showSearchResults)
                SliverToBoxAdapter(
                  child: _buildFilterOptions(),
                ),

              // Category Header
              if (!_showSearchResults)
                SliverToBoxAdapter(
                  child: _buildCategoryHeader(),
                ),

              // Brand Carousel
              if (!_showSearchResults)
                SliverToBoxAdapter(
                  child: _buildBrandCarousel(),
                ),

              // Search Results or Products
              if (_showSearchResults)
                _buildSearchResultsContent()
              else
                SliverToBoxAdapter(
                  child: _buildProductsGrid(),
                ),
            ],
          ),

          // Search loading indicator with shimmer cards
          if (_isSearching)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const SizedBox(height: 100), // Space for header
                    // Search query display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Searching for "$_currentSearchQuery"...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shimmer loading cards
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 6, // Show 6 shimmer cards
                        itemBuilder: (context, index) =>
                            _buildShimmerProductCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0xFFE8ECEF),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back arrow and logo
            Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Cart and menu icons
            Row(
              children: [
                Icon(Icons.shopping_cart_outlined,
                    color: Colors.grey[600], size: 24),
                const SizedBox(width: 16),
                Icon(Icons.menu, color: Colors.grey[600], size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _performSearch,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search Product/Category...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
          suffixIcon: _showSearchResults
              ? IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilterIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.grey[300]!,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filterOptions[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (index == 0) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 16,
                    ),
                  ],
                  if (index == 1) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.filter_list,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 16,
                    ),
                  ],
                  if (index == 2) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.flash_on,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedCategory,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${_products.length} Products',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'VIEW ALL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandCarousel() {
    if (_loadingBrands) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return GestureDetector(
            onTap: () => _onBrandTap(brand),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: brand.logoUrl != null
                        ? ClipOval(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Image.network(
                                brand.logoUrl!,
                                fit: BoxFit.contain,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.business,
                                        color: Colors.grey[400], size: 24),
                                  );
                                },
                              ),
                            ),
                          )
                        : Icon(Icons.business,
                            color: Colors.grey[400], size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    brand.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.70,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return GestureDetector(
      onTap: () => _onProductTap(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Stack(
                  children: [
                    product.photos.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8)),
                            child: Container(
                              color: Colors.white,
                              child: Image.network(
                                product.photos.first,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(8)),
                                    ),
                                    child: Image.asset(
                                      'assets/images/contracto.png',
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                            ),
                            child: Image.asset(
                              'assets/images/contracto.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                    // Top seller badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Top Seller',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Heart icon
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.favorite_border,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Product details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Expanded(
                      child: Text(
                        product.productName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Price section
                    if (product.hasPricing) ...[
                      Builder(
                        builder: (context) {
                          double? displayPrice;
                          double? displayMrp;
                          String? priceRange;

                          if (product.mrp != null) {
                            // Product has direct pricing
                            displayPrice = product.finalPrice ?? product.mrp;
                            displayMrp = product.mrp;
                          } else if (product.hasQualityOptions &&
                              product.qualityOptions.isNotEmpty) {
                            // Product has quality options - show price range
                            final prices = product.qualityOptions
                                .map((option) =>
                                    option.finalPrice ?? option.mrp ?? 0)
                                .where((price) => price > 0)
                                .toList();

                            if (prices.isNotEmpty) {
                              final minPrice =
                                  prices.reduce((a, b) => a < b ? a : b);
                              final maxPrice =
                                  prices.reduce((a, b) => a > b ? a : b);

                              if (minPrice == maxPrice) {
                                // Single price
                                displayPrice = minPrice;
                              } else {
                                // Price range
                                priceRange =
                                    '₹${minPrice.round()}-${maxPrice.round()}';
                              }
                            }
                          }

                          if (priceRange != null) {
                            return Text(
                              priceRange,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            );
                          } else if (displayPrice != null) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${displayPrice.round()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                if (displayMrp != null &&
                                    displayMrp > displayPrice) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '₹${displayMrp.round()}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      decoration: TextDecoration.lineThrough,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          } else {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFFFEDD5)),
                              ),
                              child: const Text(
                                'Price on request',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      if (product.mrp != null &&
                          product.finalPrice != null &&
                          product.mrp! > product.finalPrice!) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${((product.mrp! - product.finalPrice!) / product.mrp! * 100).round()}% OFF',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: const Text(
                          'Price on request',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Add to cart button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'ADD TO CART',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsContent() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search query display
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Results for "$_currentSearchQuery"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // Brands section
                if (_searchBrands.isNotEmpty) ...[
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Brands we deal in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shrinkWrap: true,
                      itemCount: _searchBrands.length,
                      itemBuilder: (context, index) {
                        final brand = _searchBrands[index];
                        return _buildSearchBrandCard(brand);
                      },
                    ),
                  ),
                ],

                // Products section
                if (_searchResults.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Products (${_searchResults.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.70,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];
                        return _buildProductCard(product);
                      },
                    ),
                  ),
                ],

                // No results message
                if (_searchBrands.isEmpty &&
                    _searchResults.isEmpty &&
                    !_isSearching)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No results found for "$_currentSearchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _buildRequestProductsButton(),
                      ],
                    ),
                  ),

                // Request Products button at the end of search results
                if (_searchBrands.isNotEmpty || _searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildRequestProductsButton(),
                  ),

                const SizedBox(height: 100),
              ],
            );
          }
          return null;
        },
        childCount: 1,
      ),
    );
  }

  Widget _buildSearchBrandCard(BrandModel brand) {
    return GestureDetector(
      onTap: () => _onBrandTap(brand),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: brand.logoUrl != null
                  ? ClipOval(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.network(
                          brand.logoUrl!,
                          fit: BoxFit.contain,
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.business,
                                  color: Colors.grey[400], size: 24),
                            );
                          },
                        ),
                      ),
                    )
                  : Icon(Icons.business, color: Colors.grey[400], size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              brand.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerProductCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestProductsButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _requestProducts,
        icon: const Icon(Icons.request_quote_outlined, size: 20),
        label: const Text(
          'Request Products',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _requestProducts() {
    // Navigate directly to the proper enquiry screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductEnquiryScreen(
          searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        ),
      ),
    );
  }
}
