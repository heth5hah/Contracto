import 'package:flutter/material.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';
import 'package:contracto_app/shared/widgets/cart_notification.dart';
import 'package:contracto_app/features/products/data/services/product_service.dart';
import 'package:contracto_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:contracto_app/features/brands/presentation/screens/brand_catalog_pdf_screen.dart';
import 'package:contracto_app/shared/widgets/standard_product_card.dart';
import 'package:contracto_app/features/products/presentation/screens/product_enquiry_screen.dart';
import 'package:contracto_app/core/services/realtime_sync_service.dart';
import 'dart:async';
import 'dart:ui';

class BrandProductsScreen extends StatefulWidget {
  final BrandModel brand;

  const BrandProductsScreen({
    super.key,
    required this.brand,
  });

  @override
  State<BrandProductsScreen> createState() => _BrandProductsScreenState();
}

class _BrandProductsScreenState extends State<BrandProductsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<ProductModel> _products = [];
  String _selectedCategory = 'All';
  final _productService = ProductService();
  final _realtimeSync = RealtimeSyncService();
  StreamSubscription? _productsSubscription;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearchBox = false;
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _availableCategories = ['All'];

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));
    _loadProducts();
    _setupRealtimeSync();
  }

  void _setupRealtimeSync() {
    print('🔔 Setting up real-time sync for brand: ${widget.brand.name}');
    
    // Listen to real-time product updates
    _productsSubscription = _realtimeSync.productsStream.listen(
      (productsJson) {
        print('═══════════════════════════════════════════════');
        print('🔔 REAL-TIME UPDATE RECEIVED!');
        print('📱 Screen: BrandProductsScreen (${widget.brand.name})');
        print('═══════════════════════════════════════════════');
        
        // We don't need to process the JSON data here
        // Just use it as a trigger to reload products from database
        if (mounted) {
          print('✅ Widget is mounted, reloading products...');
          _loadProducts();
        } else {
          print('⚠️  Widget is not mounted, skipping reload');
        }
      },
      onError: (error, stackTrace) {
        print('❌ Error in real-time stream: $error');
        print('Stack trace: $stackTrace');
      },
      onDone: () {
        print('⚠️  Real-time stream closed');
      },
      cancelOnError: false, // Don't cancel subscription on error
    );
    
    print('✅ Real-time sync subscription created');
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      print('🔄 Loading products for brand: ${widget.brand.name}');
      final products =
          await _productService.getProductsByBrand(widget.brand.id);
      
      print('✅ Fetched ${products.length} products for brand: ${widget.brand.name}');
      
      // Debug: Print stock status for each product
      for (var product in products) {
        print('  📦 ${product.productName}: stockStatus="${product.stockStatus}", stockQuantity=${product.stockQuantity}');
      }
      
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
          _updateAvailableCategories();
        });
        print('✅ UI updated with ${products.length} products');
      }
    } catch (e) {
      print('❌ Error loading products for brand ${widget.brand.name}: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateAvailableCategories() {
    final categories = <String>{'All'};
    for (final product in _products) {
      if (product.category != null && product.category!.isNotEmpty) {
        categories.add(product.category!);
      }
    }
    _availableCategories = categories.toList();
  }

  List<ProductModel> get _filteredProducts {
    List<ProductModel> filtered = _products;

    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((product) =>
              product.category?.toLowerCase() ==
              _selectedCategory.toLowerCase())
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((product) =>
              product.productName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (product.description
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    return filtered;
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
    });

    // Simulate search delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          // Search completed
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _toggleSearchBox() {
    setState(() {
      _showSearchBox = !_showSearchBox;
    });

    if (_showSearchBox) {
      _searchAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(FocusNode());
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              FocusScope.of(context).requestFocus(_searchFocusNode);
            }
          });
        }
      });
    } else {
      _searchAnimationController.reverse();
      _clearSearch();
    }
  }

  void _onProductTap(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Minimal Premium App Bar
                SliverAppBar(
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  elevation: 0,
                  pinned: true,
                  centerTitle: true,
                  title: Text(
                    widget.brand.name,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Icon(Icons.arrow_back, color: Colors.grey[800], size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _showSearchBox ? const Color(0xFF4F46E5) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _showSearchBox ? const Color(0xFF4F46E5) : Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Icon(Icons.search, color: _showSearchBox ? Colors.white : Colors.grey[800], size: 20),
                      ),
                      onPressed: _toggleSearchBox,
                    ),
                    if (widget.brand.catalogUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                            ),
                            child: Icon(Icons.picture_as_pdf_outlined, color: Colors.grey[800], size: 20),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BrandCatalogPdfScreen(brand: widget.brand),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),

                // Brand Header Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Large Logo
                          Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                            ),
                            child: widget.brand.logoUrl != null
                                ? CustomNetworkImage(
                                    imageUrl: widget.brand.logoUrl!,
                                    fit: BoxFit.contain,
                                    errorWidget: Icon(Icons.business, color: Colors.grey[400], size: 32),
                                  )
                                : Icon(Icons.business, color: Colors.grey[400], size: 32),
                          ),
                          const SizedBox(height: 16),
                          // Brand Name
                          Text(
                            widget.brand.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.brand.description != null && widget.brand.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.brand.description!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Official Partner Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Authorized Partner',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Search Box
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _searchAnimation,
                    builder: (context, child) {
                      return ClipRRect(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: _showSearchBox ? 60 : 0,
                          margin: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: _showSearchBox ? 16 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: _showSearchBox
                              ? TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Search in ${widget.brand.name}...',
                                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                    border: InputBorder.none,
                                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4F46E5)),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                      onPressed: _toggleSearchBox,
                                    ),
                                  ),
                                  onChanged: _performSearch,
                                  onSubmitted: _performSearch,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                // Category filter tabs
                SliverToBoxAdapter(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _availableCategories.length,
                      itemBuilder: (context, index) {
                        final category = _availableCategories[index];
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Products Count Info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_filteredProducts.length} Items found',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_selectedCategory != 'All')
                          Text(
                            _selectedCategory,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Products Grid
                if (_filteredProducts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                            ),
                            child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different category or search term.',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: _buildRequestProductsButton(),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.70,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildProductCard(_filteredProducts[index]);
                        },
                        childCount: _filteredProducts.length,
                      ),
                    ),
                  ),

                // Bottom Padding + Request Button if items exist
                if (_filteredProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                      child: _buildRequestProductsButton(),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    // Calculate discount percentage if applicable
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
      onTap: () => _onProductTap(product),
      onAddToCart: () {
        // Stock Check
        if (product.stockQuantity != null) {
          final currentQty = CartService().cartItems
              .where((i) => i.product.id == product.id)
              .fold(0.0, (sum, i) => sum + i.quantity);
          if (currentQty + 1 > product.stockQuantity!) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Only ${product.stockQuantity} items available in stock'),
                backgroundColor: const Color(0xFFF59E0B),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
        }

        // Add to cart logic
        CartService().addToCart(product, 1.0);
        
        // Add to cart notification with View Cart action
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
        // Request quote logic can be implemented here
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

  Widget _buildRequestProductsButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _requestProducts,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.request_quote_outlined, color: Color(0xFF4F46E5), size: 22),
                SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Request Missing Products',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _requestProducts() {
    // Navigate to the unified Product Enquiry screen, prefilled with brand name
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductEnquiryScreen(
          searchQuery: widget.brand.name,
        ),
      ),
    );
  }
}
