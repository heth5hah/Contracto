import 'package:flutter/material.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/brands/data/services/brand_service.dart';
import 'package:contracto_app/features/brands/presentation/screens/brand_products_screen.dart';
import 'package:contracto_app/features/brands/presentation/screens/all_brands_screen.dart';
import 'package:contracto_app/features/categories/data/models/category_model.dart';
import 'package:contracto_app/features/categories/data/services/category_service.dart';
import 'package:contracto_app/features/categories/presentation/screens/all_categories_screen.dart';
import 'package:contracto_app/features/categories/presentation/screens/category_products_screen.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/features/products/data/services/product_service.dart';
import 'package:contracto_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:contracto_app/features/address/data/models/address_model.dart';
import 'package:contracto_app/features/address/data/services/address_service.dart';
import 'package:contracto_app/features/address/presentation/screens/address_screen.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/shared/widgets/product_grid_1x3.dart';
import 'package:contracto_app/features/products/presentation/screens/product_search_screen.dart';
import 'package:contracto_app/core/services/realtime_sync_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _brandService = BrandService();
  final _productService = ProductService();
  final _addressService = AddressService();
  final _categoryService = CategoryService();
  final _realtimeSync = RealtimeSyncService();
  StreamSubscription? _productsSubscription;
  StreamSubscription? _brandsSubscription;
  StreamSubscription? _categoriesSubscription;
  List<BrandModel> _brands = [];
  List<ProductModel> _products = [];
  List<ProductModel> _featuredProducts = [];
  List<CategoryModel> _categories = [];
  List<AddressModel> _addresses = [];
  bool _isLoadingBrands = true;
  bool _isLoadingProducts = true;
  bool _isLoadingFeaturedProducts = true;
  bool _isLoadingCategories = true;
  bool _isLoadingAddresses = true;
  AddressModel? _selectedAddress;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserInfo();
    _loadBrands();
    _loadProducts();
    _loadFeaturedProducts();
    _loadCategories();
    _loadAddresses();
    _setupRealtimeSync();
  }

  void _setupRealtimeSync() {
    // Listen to real-time product updates
    _productsSubscription = _realtimeSync.productsStream.listen(
      (productsJson) {
        print('Real-time products update detected in Home screen');
        if (mounted) {
          _loadProducts();
          _loadFeaturedProducts();
        }
      },
      onError: (error, stackTrace) {
        print('Error in products real-time stream: $error');
      },
      cancelOnError: false,
    );
    
    // Listen to real-time brand updates
    _brandsSubscription = _realtimeSync.brandsStream.listen(
      (brandsJson) {
        print('Real-time brands update detected in Home screen');
        if (mounted) {
          _loadBrands();
        }
      },
      onError: (error, stackTrace) {
        print('Error in brands real-time stream: $error');
      },
      cancelOnError: false,
    );
    
    // Listen to real-time category updates
    _categoriesSubscription = _realtimeSync.categoriesStream.listen(
      (categoriesJson) {
        print('Real-time categories update detected in Home screen');
        if (mounted) {
          _loadCategories();
        }
      },
      onError: (error, stackTrace) {
        print('Error in categories real-time stream: $error');
      },
      cancelOnError: false,
    );
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _productsSubscription?.cancel();
    _brandsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser != null) {
        // Try to get user data from our users table by email
        final userData = await SupabaseService.client
            .from('users')
            .select()
            .eq('email', currentUser.email!)
            .maybeSingle();

        if (userData != null) {
          setState(() {
            _userName = userData['name'] ?? 'User';
          });
        } else {
          // Fallback to auth user metadata
          setState(() {
            _userName = currentUser.userMetadata?['name'] ?? 'User';
          });
        }
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _loadBrands() async {
    try {
      setState(() => _isLoadingBrands = true);
      final brands = await _brandService.getBrands();
      setState(() {
        _brands = brands;
        _isLoadingBrands = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading brands: $e')),
      );
      setState(() => _isLoadingBrands = false);
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoadingProducts = true);
      final products = await _productService.getProducts();
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadFeaturedProducts() async {
    try {
      setState(() => _isLoadingFeaturedProducts = true);
      final products = await _productService.getFeaturedProducts();
      setState(() {
        _featuredProducts = products;
        _isLoadingFeaturedProducts = false;
      });
    } catch (e) {
      print('Error loading featured products: $e');
      setState(() => _isLoadingFeaturedProducts = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() => _isLoadingCategories = true);
      final categories = await _categoryService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadAddresses() async {
    try {
      setState(() => _isLoadingAddresses = true);
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser != null) {
        final addresses = await _addressService.getAddresses();
        setState(() {
          _addresses = addresses;
          _selectedAddress = addresses.isNotEmpty
              ? addresses
                  .first // Just use the first address since default is not supported
              : null;
          _isLoadingAddresses = false;
        });
      } else {
        // No user logged in, set loading to false
        setState(() => _isLoadingAddresses = false);
      }
    } catch (e) {
      print('Error loading addresses: $e');
      setState(() => _isLoadingAddresses = false);
    }
  }

  void _navigateToBrandProducts(BrandModel brand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandProductsScreen(brand: brand),
      ),
    );
  }

  void _navigateToProductDetails(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  void _viewAllBrands() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllBrandsScreen(),
      ),
    );
  }

  void _navigateToCategoryProducts(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryProductsScreen(category: category),
      ),
    );
  }

  void _viewAllCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllCategoriesScreen(),
      ),
    );
  }

  void _showAddressBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Address',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddressScreen(),
                        ),
                      ).then((_) => _loadAddresses());
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add New'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingAddresses
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    )
                  : _addresses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No addresses found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first address to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddressScreen(),
                                    ),
                                  ).then((_) => _loadAddresses());
                                },
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Add Address'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _addresses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final address = _addresses[index];
                            final isSelected =
                                _selectedAddress?.id == address.id;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedAddress = address;
                                });
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF3B82F6)
                                        : Colors.grey[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : Colors.grey[400],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        address.label == 'Home'
                                            ? Icons.home_outlined
                                            : address.label == 'Office'
                                                ? Icons.business_outlined
                                                : address.label == 'Site'
                                                    ? Icons.domain_outlined
                                                    : Icons.location_on_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                address.label,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? const Color(0xFF3B82F6)
                                                      : const Color(0xFF1E293B),
                                                ),
                                              ),
                                              // Default address indicator not supported in simplified schema
                                              // if (address.isDefault) ...[
                                              //   const SizedBox(width: 8),
                                              //   Container(
                                              //     padding: const EdgeInsets
                                              //         .symmetric(
                                              //       horizontal: 6,
                                              //       vertical: 2,
                                              //     ),
                                              //     decoration: BoxDecoration(
                                              //       color:
                                              //           const Color(0xFF10B981),
                                              //       borderRadius:
                                              //           BorderRadius.circular(
                                              //               4),
                                              //     ),
                                              //     child: const Text(
                                              //       'Default',
                                              //       style: TextStyle(
                                              //         fontSize: 10,
                                              //         fontWeight:
                                              //             FontWeight.w500,
                                              //         color: Colors.white,
                                              //       ),
                                              //     ),
                                              //   ),
                                              // ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            address.fullAddress,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF3B82F6),
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildBrandCard(BrandModel brand, int index) {
    return Hero(
      tag: 'brand_${brand.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToBrandProducts(brand),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 50,
                  width: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: brand.logoUrl != null
                      ? Image.network(
                          brand.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.business,
                            size: 24,
                            color: Colors.grey[400],
                          ),
                        )
                      : Icon(
                          Icons.business,
                          size: 24,
                          color: Colors.grey[400],
                        ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    brand.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    return InkWell(
      onTap: () => _navigateToCategoryProducts(category),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(30),
              ),
              child: category.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        category.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.category,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.category,
                      size: 30,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCategoryChip() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: _viewAllCategories,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.apps,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                'All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(CategoryModel category) {
    // Get appropriate icon based on category name
    IconData categoryIcon = Icons.build;
    switch (category.name.toUpperCase()) {
      case 'TOOLS':
        categoryIcon = Icons.build;
        break;
      case 'ELECTRICAL':
        categoryIcon = Icons.electrical_services;
        break;
      case 'PLUMBING':
        categoryIcon = Icons.plumbing;
        break;
      case 'HARDWARE':
        categoryIcon = Icons.hardware;
        break;
      case 'BATH & FAUCET':
        categoryIcon = Icons.bathroom;
        break;
      default:
        categoryIcon = Icons.category;
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _navigateToCategoryProducts(category),
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                categoryIcon,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, int index) {
    return Hero(
      tag: 'product_${product.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProductDetails(product),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: product.photos.isNotEmpty
                              ? Container(
                                  color: Colors.white,
                                  child: Image.network(
                                    product.photos.first,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Image.asset(
                                      'assets/images/contracto.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.white,
                                  child: Image.asset(
                                    'assets/images/contracto.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // Product Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Tag
                            if (product.category != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product.category!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // Product Name
                            Text(
                              product.productName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Price Section
                            if (product.hasPricing) ...[
                              Builder(
                                builder: (context) {
                                  double? displayPrice;
                                  double? displayMrp;
                                  double? displayDiscountPercent;

                                  if (product.mrp != null) {
                                    // Product has direct pricing
                                    displayPrice =
                                        product.finalPrice ?? product.mrp;
                                    displayMrp = product.mrp;
                                    displayDiscountPercent =
                                        product.discountPercent;
                                  } else if (product.hasQualityOptions &&
                                      product.qualityOptions.isNotEmpty) {
                                    // Product has quality options - show price range
                                    final prices = product.qualityOptions
                                        .map((option) =>
                                            option.finalPrice ??
                                            option.mrp ??
                                            0)
                                        .where((price) => price > 0)
                                        .toList();

                                    if (prices.isNotEmpty) {
                                      final minPrice = prices
                                          .reduce((a, b) => a < b ? a : b);
                                      final maxPrice = prices
                                          .reduce((a, b) => a > b ? a : b);

                                      if (minPrice == maxPrice) {
                                        // Single price
                                        displayPrice = minPrice;
                                      } else {
                                        // Price range
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${minPrice.round()} - ₹${maxPrice.round()}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF3B82F6),
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    }
                                  }

                                  if (displayPrice != null) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${displayPrice.round()}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                        if (displayMrp != null &&
                                            displayMrp > displayPrice) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '₹${displayMrp.round()}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  } else {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFFFEDD5),
                                        ),
                                      ),
                                      child: const Text(
                                        'Price on request',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              if (product.finalPrice != null &&
                                  product.mrp != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${((product.mrp! - product.finalPrice!) / product.mrp! * 100).round()}% OFF',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFFEDD5),
                                  ),
                                ),
                                child: const Text(
                                  'Price on request',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Sale Badge (if applicable)
                if (product.finalPrice != null && product.mrp != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_offer,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'SALE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 160,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1.0,
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: SizedBox(
                height: 160,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting and Notification
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()},',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Mr. $_userName',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            size: 24,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Address Dropdown
                    GestureDetector(
                      onTap: _showAddressBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 20,
                              color: Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _isLoadingAddresses
                                  ? const Text(
                                      'Loading address...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    )
                                  : Text(
                                      _selectedAddress?.label ?? 'Add Address',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1E293B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductSearchScreen(),
                          ),
                        );
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search products...',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: Color(0xFF64748B),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop by Brand Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Shop by Brand',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          TextButton(
                            onPressed: _viewAllBrands,
                            child: const Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Brands Grid (3x3)
                      if (_isLoadingBrands)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        )
                      else if (_brands.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/images/contracto.png',
                                  height: 64,
                                  width: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No brands available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 120, // Fixed height for horizontal scroll
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _brands.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 100, // Fixed width for each brand card
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: _buildBrandCard(_brands[index], index),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 32),
                      
                      // Featured Products Section
                      if (!_isLoadingFeaturedProducts && _featuredProducts.isNotEmpty) ...[
                        ProductGrid1x3(
                          products: _featuredProducts,
                          title: 'Featured Products',
                          onProductTap: _navigateToProductDetails,
                          onViewAll: () {
                            // Navigate to all featured products
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProductSearchScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                      
                      // Categories Section
                      const SizedBox(height: 16),
                      // Categories Horizontal List
                      if (_isLoadingCategories)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        )
                      else if (_categories.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.category_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No categories available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            itemCount: _categories.length + 1, // +1 for "All"
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // "All" category
                                return _buildAllCategoryChip();
                              }
                              return _buildCategoryChip(_categories[index - 1]);
                            },
                          ),
                        ),

                      // Category-wise Products
                      if (_categories.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        // Products Grid for first category
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _categoryService.getProductsByCategoryName(
                              _categories.first.name),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No products available',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final products = snapshot.data!
                                .map((data) => ProductModel.fromJson(data))
                                .toList();

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.70,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: products.length > 4
                                  ? 4
                                  : products.length, // Show max 4 products
                              itemBuilder: (context, index) {
                                return _buildProductCard(
                                    products[index], index);
                              },
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
