import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
import 'package:provider/provider.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/brands/data/services/brand_service.dart';
import 'package:contracto_app/features/brands/presentation/screens/all_brands_screen.dart';
import 'package:contracto_app/features/brands/presentation/screens/brand_products_screen.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/features/products/data/services/product_service.dart';
import 'package:contracto_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:contracto_app/features/products/presentation/screens/product_enquiry_screen.dart';
import 'package:contracto_app/features/auth/data/services/user_service.dart';
import 'package:contracto_app/features/categories/data/models/category_model.dart';
import 'package:contracto_app/features/categories/data/services/category_service.dart';
import 'package:contracto_app/features/categories/presentation/screens/all_categories_screen.dart';
import 'package:contracto_app/features/home/data/services/image_slides_service.dart';
import 'package:contracto_app/shared/widgets/standard_product_card.dart';
import 'package:contracto_app/features/quotations/data/services/quote_request_cart_service.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';
import 'package:contracto_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:contracto_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/auth/presentation/screens/login_screen.dart';
import 'package:contracto_app/shared/widgets/cart_notification.dart';
import 'package:contracto_app/core/services/location_service.dart';
import 'package:contracto_app/features/address/data/services/address_service.dart';
import 'package:contracto_app/features/address/presentation/screens/address_screen.dart';

class BlinkitStyleHome extends StatefulWidget {
  /// Optional callback to switch the parent navigation tab.
  /// Called with (tabIndex, optionalQuoteId) when navigating from a notification.
  final void Function(int tabIndex, {String? quoteId})? onSwitchToTab;

  const BlinkitStyleHome({super.key, this.onSwitchToTab});

  @override
  State<BlinkitStyleHome> createState() => BlinkitStyleHomeState();
}

class BlinkitStyleHomeState extends State<BlinkitStyleHome>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Controllers for horizontal scrollable widgets
  late final ScrollController _categoryScrollController;
  late final ScrollController _brandScrollController;
  late final ScrollController _brandScrollController2;
  late final ScrollController _featuredProductsScrollController;
  late final ScrollController _searchBrandScrollController;
  late final ScrollController _featuredCardsScrollController;
  late final ScrollController _offerCardsScrollController;
  late final ScrollController _categoryProductsScrollController;
  late final ScrollController _moreProductsScrollController;
  final PageController _imageSlidesPageController = PageController();
  late PageController _contentPageController;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _tabController;

  bool _isHeaderCollapsed = false;
  bool _isLoggedIn = false;
  String _userAddress = 'Select delivery address';
  List<BrandModel> _brands = [];
  List<ProductModel> _searchResults = [];
  List<BrandModel> _searchBrands = [];
  List<CategoryModel> _categories = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _categoryProducts = [];
  final Map<String, List<ProductModel>> _categoryProductsCache = {};
  // Cache for category section data
  final Map<String, List<CategoryItem>> _categorySectionCache = {};
  String? _selectedCategoryName;
  String? _selectedSubcategoryName; // Track selected subcategory filter
  int _selectedCategoryIndex = 0; // Track selected category index
  List<ImageSlide> _imageSlides = [];
  bool _loadingBrands = true;
  bool _loadingCategories = true;
  bool _loadingProducts = true;
  final Set<String> _loadingCategoryNames = {};
  bool _isSearching = false;
  bool _showSearchResults = false;
  bool _showCategoryResults = false;
  String _currentSearchQuery = '';
  List<Map<String, dynamic>> _userAddresses = [];
  bool _loadingUserData = true;
  final bool _hasResetAtTop = false; // Flag to prevent multiple resets
  bool _isBusinessAccount = false; // Track if user is a business account

  // Caching flags to prevent reloading content
  bool _brandsLoaded = false;
  bool _categoriesLoaded = false;
  bool _featuredProductsLoaded = false;
  bool _imageSlidesLoaded = false;

  final _brandService = BrandService();
  final _productService = ProductService();
  final _userService = UserService();
  final _categoryService = CategoryService();
  final _imageSlidesService = ImageSlidesService();
  final _businessCreditService = BusinessCreditService();
  final _addressService = AddressService();

  // Voice Search
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();

    // Initialize ScrollControllers
    _categoryScrollController = ScrollController();
    _brandScrollController = ScrollController();
    _brandScrollController2 = ScrollController();
    _featuredProductsScrollController = ScrollController();
    _searchBrandScrollController = ScrollController();
    _featuredCardsScrollController = ScrollController();
    _offerCardsScrollController = ScrollController();
    _categoryProductsScrollController = ScrollController();
    _moreProductsScrollController = ScrollController();

    _checkAuthStatus();
    _loadBrands();
    _loadCategories();
    _loadFeaturedProducts();
    _loadImageSlides();
    _initSpeech();
    _loadUserData();
    _scrollController.addListener(_onScroll);

    _contentPageController = PageController(initialPage: 0);
    _contentPageController.addListener(_onPageChanged);

    // Initialize real-time sync for products
    _productService.initializeRealtimeSync();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _tabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _categoryScrollController.dispose();
    _brandScrollController.dispose();
    _brandScrollController2.dispose();
    _featuredProductsScrollController.dispose();
    _searchBrandScrollController.dispose();
    _featuredCardsScrollController.dispose();
    _offerCardsScrollController.dispose();
    _categoryProductsScrollController.dispose();
    _moreProductsScrollController.dispose();
    _imageSlidesPageController.dispose();
    _contentPageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (mounted) setState(() {});
  }

  void _startListening() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    if (!_speechEnabled) {
      _speechEnabled = await _speechToText.initialize();
    }

    await _speechToText.listen(onResult: _onSpeechResult);
    if (mounted) {
      setState(() {
        _isListening = true;
      });
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        _searchController.text = result.recognizedWords;
      });

      if (result.finalResult) {
        setState(() {
          _isListening = false;
        });
        _performSearch(result.recognizedWords);
      }
    }
  }

  void _checkAuthStatus() {
    final user = SupabaseService.instance.currentUser;
    if (mounted) {
      setState(() {
        _isLoggedIn = user != null;
      });
      if (_isLoggedIn) {
        _loadAddresses();
      }
    }
  }

  Future<void> _loadAddresses() async {
    if (!_isLoggedIn) return;

    try {
      print('[BlinkitHome] Loading addresses...');
      final addresses = await _addressService.getAddresses();

      if (mounted) {
        setState(() {
          _userAddresses = addresses
              .map((a) => {
                    'id': a.id,
                    'label': a.label ?? 'Home',
                    'address': a.fullAddress,
                    'is_default': a.isDefault
                  })
              .toList();

          // Auto-select address logic
          if (_userAddresses.isNotEmpty) {
            // If current selection is invalid or default
            if (_userAddress == 'Select delivery address' ||
                _userAddress.isEmpty) {
              final defaultAddr = addresses.firstWhere((a) => a.isDefault,
                  orElse: () => addresses.first);
              _userAddress = defaultAddr.label ?? 'Home';
            }
          }
        });
        print(
            '[BlinkitHome] Loaded ${_userAddresses.length} addresses. Selected: $_userAddress');
      }
    } catch (e) {
      print('[BlinkitHome] Error loading addresses: $e');
    }
  }

  Future<void> _loadUserData() async {
    if (!_isLoggedIn) {
      if (mounted) {
        setState(() {
          _loadingUserData = false;
          _isBusinessAccount = false;
        });
      }
      return;
    }

    try {
      final userData = await _userService.getCurrentUserData();
      final addresses = await _userService.getUserAddresses();

      // Check if user is a business account
      // Check multiple possible fields: user_type, accountType, or check if company_name exists
      final userType = userData?['user_type'] as String?;
      final hasCompanyName = userData?['company_name'] != null &&
          (userData?['company_name'] as String).isNotEmpty;

      // Also check if user has a business credit account (most reliable indicator)
      final creditAccount = await _businessCreditService.getCreditAccount();
      final hasCreditAccount = creditAccount != null;

      final isBusiness = userData != null &&
          (userType == 'company' || hasCompanyName || hasCreditAccount);

      print(
          'HomeScreen: User data loaded - user_type = $userType, company_name = ${userData?['company_name']}, hasCreditAccount = $hasCreditAccount, isBusiness = $isBusiness');
      print('HomeScreen: Full user data keys = ${userData?.keys.toList()}');

      if (mounted) {
        setState(() {
          _userAddresses = addresses;
          _loadingUserData = false;
          _isBusinessAccount = isBusiness;

          // Set default address
          if (addresses.isNotEmpty) {
            final defaultAddress = addresses.first;
            _userAddress = defaultAddress['label'] ?? 'Home';
          } else {
            _userAddress = 'Add delivery address';
          }
        });
        print(
            'HomeScreen: State updated - _isLoggedIn = $_isLoggedIn, _isBusinessAccount = $_isBusinessAccount');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingUserData = false;
          _isBusinessAccount = false;
          _userAddress = 'Add delivery address';
        });
      }
    }
  }

  Future<void> _loadBrands() async {
    if (_brandsLoaded) return; // Skip if already loaded

    try {
      print('Loading brands...');
      final brands = await _brandService.getFeaturedBrands();
      print('Brands loaded: ${brands.length}');
      print('Brand names: ${brands.map((b) => b.name).toList()}');
      if (mounted) {
        setState(() {
          _brands = brands;
          _loadingBrands = false;
          _brandsLoaded = true; // Mark as loaded
        });
        print('Brands state updated: ${_brands.length}');
        print('Final brand names: ${_brands.map((b) => b.name).toList()}');
      }
    } catch (e) {
      print('Error loading brands: $e');
      if (mounted) {
        setState(() => _loadingBrands = false);
      }
    }
  }

  Future<void> _loadCategories() async {
    if (_categoriesLoaded) return; // Skip if already loaded

    try {
      if (mounted) {
        setState(() => _loadingCategories = true);
      }
      final categories = await _categoryService.getCategories();
      if (mounted) {
        setState(() {
          // Sort: move waterproofing to end
          final sorted = categories.take(8).toList();
          sorted.sort((a, b) {
            final aIsWp = a.name.toLowerCase().contains('waterproof');
            final bIsWp = b.name.toLowerCase().contains('waterproof');
            if (aIsWp && !bIsWp) return 1;
            if (!aIsWp && bIsWp) return -1;
            return 0;
          });
          _categories = sorted;
          _loadingCategories = false;
          _categoriesLoaded = true; // Mark as loaded
        });
        print('Categories loaded: ${_categories.length}');
        // Debug: Print category image URLs
        for (var category in _categories) {
          print('Category: ${category.name}, ImageURL: ${category.imageUrl}');
          if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
            print('Image URL is not null/empty for ${category.name}');
            // Test if URL is accessible
            try {
              final uri = Uri.parse(category.imageUrl!);
              print('Parsed URI for ${category.name}: $uri');
            } catch (e) {
              print('Error parsing URL for ${category.name}: $e');
            }
          } else {
            print('Image URL is null/empty for ${category.name}');
          }
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  Future<void> _loadFeaturedProducts() async {
    if (_featuredProductsLoaded) return; // Skip if already loaded

    try {
      if (mounted) {
        setState(() => _loadingProducts = true);
      }
      final products = await _productService.getFeaturedProducts();
      if (mounted) {
        setState(() {
          _featuredProducts = products;
          _loadingProducts = false;
          _featuredProductsLoaded = true; // Mark as loaded
        });
        print('Featured products loaded: ${_featuredProducts.length}');
      }
    } catch (e) {
      print('Error loading products: $e');
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  Future<void> _loadImageSlides() async {
    if (_imageSlidesLoaded) return; // Skip if already loaded

    try {
      final slides = await _imageSlidesService.getActiveSlides();

      // FIX: Force update the Steel slide with the local asset
      // This ensures the new image shows up even if DB update failed
      final updatedSlides = slides.map((slide) {
        if (slide.title == 'Steel' || slide.sortOrder == 2) {
          return ImageSlide(
            id: slide.id,
            title: slide.title ?? 'Steel',
            description: slide.description ?? 'Premium quality steel products',
            imageUrl: 'assets/images/steel_warehouse.png', // Use local asset
            linkUrl: slide.linkUrl,
            brandId: slide.brandId,
            sortOrder: slide.sortOrder,
            isActive: slide.isActive,
            createdAt: slide.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        return slide;
      }).toList();

      if (mounted) {
        setState(() {
          _imageSlides = updatedSlides;
          _imageSlidesLoaded = true; // Mark as loaded
        });
        print('Image slides loaded: ${_imageSlides.length}');
      }
    } catch (e) {
      print('Error loading image slides: $e');
    }
  }

  Future<void> _loadCategoryProducts(String categoryName) async {
    try {
      if (mounted) {
        setState(() {
          _loadingCategoryNames.add(categoryName);
          _selectedCategoryName = categoryName;
          _selectedSubcategoryName = null;
          _showCategoryResults = true;
          _showSearchResults = false;
        });
      }

      // Serve from cache if available
      if (_categoryProductsCache.containsKey(categoryName)) {
        if (mounted) {
          setState(() {
            _categoryProducts = _categoryProductsCache[categoryName]!;
            _loadingCategoryNames.remove(categoryName);
          });
          print('Category products served from cache for $categoryName');
        }
        return;
      }

      final products =
          await _productService.getProductsByCategory(categoryName);
      if (mounted) {
        setState(() {
          _categoryProducts = products;
          _categoryProductsCache[categoryName] = products;
          _loadingCategoryNames.remove(categoryName);
        });
        print(
            'Category products loaded: ${_categoryProducts.length} for $categoryName');
      }
    } catch (e) {
      print('Error loading category products: $e');
      if (mounted) {
        setState(() => _loadingCategoryNames.remove(categoryName));
      }
    }
  }

  void _showAllCategories() {
    if (mounted) {
      setState(() {
        _selectedCategoryIndex = 0;
        _showCategoryResults = false;
        _selectedCategoryName = null;
        _selectedSubcategoryName = null;
        _categoryProducts.clear();
      });
      print(
          'Switched to All categories - cache status: ${_categorySectionCache.length} sections cached');
    }
  }

  void _clearCache() {
    _categoryProductsCache.clear();
    _categorySectionCache.clear();
    print('Cache cleared');
  }

  void _onImageSlideTap(ImageSlide slide) async {
    // If slide has a brand associated, navigate to brand profile
    if (slide.brandId != null) {
      try {
        final brand =
            await _imageSlidesService.getBrandForSlide(slide.brandId!);
        if (brand != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrandProductsScreen(brand: brand),
            ),
          );
        }
      } catch (e) {
        print('Error navigating to brand: $e');
        // Fallback: show a snackbar or handle error gracefully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open brand profile'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else if (slide.linkUrl != null) {
      // Fallback: if there's a linkUrl but no brand, you could handle it here
      // For now, we'll just print it
      print('Image slide tapped with link: ${slide.linkUrl}');
    } else {
      // No brand or link associated - could show a message or do nothing
      print('Image slide tapped but no action defined');
    }
  }

  Widget _buildCategoryContent() {
    // Don't show category content if we're showing category results
    if (_showCategoryResults) {
      return const SizedBox.shrink();
    }

    if (_selectedCategoryIndex == 0) {
      // Show original content for "All" tab
      return _buildOriginalContent();
    } else {
      // Show category-specific content with products
      final category = _categories[_selectedCategoryIndex - 1];
      return _buildCategoryProductsContent(category);
    }
  }

  Widget _buildOriginalContent() {
    return Column(
      children: [
        // Image Slides section
        if (_imageSlides.isNotEmpty) ...[
          _buildImageSlidesSection(),
          const SizedBox(height: 24),
        ],

        // Shop by Brand section
        _buildBrandSection(),
        const SizedBox(height: 32),

        // Featured Products section
        _buildFeaturedProductsSection(),

        // END OF HOME SCREEN - Contracto branding footer
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Image.asset(
                'assets/images/contracto.png',
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your trusted partner in construction supplies',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '©2026 Contracto. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildImageSlidesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: _imageSlides.isEmpty
          ? const SizedBox.shrink()
          : AspectRatio(
              aspectRatio: 21 / 9, // Shorter banner matching sample image
              child: PageView.builder(
                controller: _imageSlidesPageController,
                itemCount: _imageSlides.length,
                itemBuilder: (context, index) {
                  final slide = _imageSlides[index];
                  return GestureDetector(
                      onTap: () => _onImageSlideTap(slide),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Colors.grey[
                                100], // Background color for transparent areas
                            child: Stack(
                              children: [
                                // Background image
                                (slide.imageUrl.startsWith('http'))
                                    ? Image.network(
                                        slide.imageUrl,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: const Color(0xFF4F46E5),
                                            child: const Icon(
                                              Icons.image,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      )
                                    : Image.asset(
                                        slide.imageUrl,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: const Color(0xFF4F46E5),
                                            child: const Icon(
                                              Icons.image,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      ),
                                // Content overlay
                                Positioned(
                                  bottom: 20,
                                  left: 20,
                                  right: 20,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (slide.title != null)
                                        Text(
                                          slide.title!,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      if (slide.description != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          slide.description!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ));
                },
              ),
            ),
    );
  }

  Widget _buildBrandSection() {
    if (_loadingBrands) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5, // Show 5 shimmer cards
          itemBuilder: (context, index) => _buildShimmerBrandCard(),
        ),
      );
    }

    if (_brands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop by Brand',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AllBrandsScreen(),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: GridView.builder(
              controller: _brandScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              key: const ValueKey('brands_grid'),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: _brands.length,
              itemBuilder: (context, index) {
                final brand = _brands[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BrandProductsScreen(brand: brand),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          Colors.white.withValues(alpha: 0.50),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF1E293B).withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.08)),
                            ),
                            child: brand.logoUrl != null &&
                                    brand.logoUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CustomNetworkImage(
                                      imageUrl: brand.logoUrl!,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      errorWidget: Center(
                                        child: Text(
                                          brand.name
                                              .substring(0, 2)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      brand.name.substring(0, 2).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            brand.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.1,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    );
  }

  Widget _buildFeaturedProductsSection() {
    if (_loadingProducts) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Featured Products',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
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
              itemCount: 6, // Show 6 shimmer cards in 2-column grid
              itemBuilder: (context, index) => _buildShimmerProductCard(),
            ),
          ),
        ],
      );
    }

    if (_featuredProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Featured Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
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
            itemCount: _featuredProducts.length,
            itemBuilder: (context, index) {
              final product = _featuredProducts[index];
              const pastelColors = [
                Color(0xFFFFFACD),
                Color(0xFFFF9999),
                Color(0xFFE6E6FA),
                Color(0xFFD4F4DD),
              ];
              final bgColor = pastelColors[index % pastelColors.length];
              return _buildProductCard(product, imageBackgroundColor: bgColor);
            },
          ),
        ),
        const SizedBox(height: 32),

        // ── Shop by Category Grid ──
        if (!_loadingCategories && _categories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop by Category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final selectedCategoryName = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AllCategoriesScreen(),
                      ),
                    );
                    if (selectedCategoryName != null && mounted) {
                      final catIndex = _categories.indexWhere(
                          (c) => c.name == selectedCategoryName);
                      if (catIndex >= 0) {
                        setState(() {
                          _selectedCategoryIndex = catIndex + 1;
                        });
                        _contentPageController.jumpToPage(catIndex + 1);
                      }
                    }
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index + 1; // +1 because 0 is "All"
                    });
                    _contentPageController.jumpToPage(index + 1);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: category.name.toLowerCase().contains('waterproof')
                                  ? _build3DCategoryIcon(category)
                                  : _buildCategoryImage(category),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                          child: Text(
                            _toTitleCase(category.name),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Combined 3D categories image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/cat_all_3d.png',
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Explore All Categories
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () async {
              final selectedCategoryName = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllCategoriesScreen(),
                ),
              );
              if (selectedCategoryName != null && mounted) {
                // Find the category index and select it
                final catIndex = _categories.indexWhere(
                    (c) => c.name == selectedCategoryName);
                if (catIndex >= 0) {
                  setState(() {
                    _selectedCategoryIndex = catIndex + 1; // +1 because 0 is "All"
                  });
                  _contentPageController.jumpToPage(catIndex + 1);
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_view_rounded,
                      size: 18, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text(
                    'Explore All Categories',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: Color(0xFF6366F1)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreProductsGridSection() {
    if (_loadingProducts) {
      return const SizedBox.shrink();
    }

    if (_featuredProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'More Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400, // Height for 2 rows of products
          child: ListView.builder(
            controller: _moreProductsScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: (_featuredProducts.length / 6).ceil(),
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * 6;
              final endIndex = (startIndex + 6 < _featuredProducts.length)
                  ? startIndex + 6
                  : _featuredProducts.length;
              final pageProducts =
                  _featuredProducts.sublist(startIndex, endIndex);

              return Container(
                width: MediaQuery.of(context).size.width -
                    32, // Full width minus padding
                margin: const EdgeInsets.only(right: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.70,
                  ),
                  itemCount: pageProducts.length,
                  itemBuilder: (context, index) {
                    final product = pageProducts[index];
                    return _buildProductCard(product);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryImage(CategoryModel category) {
    String? localAsset;
    if (category.name.toLowerCase().contains('waterproofing')) {
      localAsset = 'assets/images/waterproofing.png';
    } else if (category.name.toLowerCase().contains('switches')) {
      localAsset = 'assets/images/switches.png';
    } else if (category.name.toLowerCase().contains('lighting')) {
      localAsset = 'assets/images/lighting.png';
    } else if (category.name.toLowerCase().contains('hardware')) {
      localAsset = 'assets/images/hardware.png';
    } else if (category.name.toLowerCase().contains('electrical')) {
      localAsset = 'assets/images/electrical.png';
    } else if (category.name.toLowerCase().contains('cables')) {
      localAsset = 'assets/images/cables.png';
    }

    if (localAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          localAsset,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
        ),
      );
    }

    if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomNetworkImage(
          imageUrl: category.imageUrl!,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorWidget: Icon(
            _getCategoryIcon(category.iconName ?? category.name),
            color: const Color(0xFF4F46E5),
            size: 24,
          ),
        ),
      );
    }

    return Icon(
      _getCategoryIcon(category.iconName ?? category.name),
      color: const Color(0xFF4F46E5),
      size: 24,
    );
  }

  Widget _buildCachedCategoryProducts(CategoryModel category) {
    // Check if we have cached products for this category
    if (_categoryProductsCache.containsKey(category.name)) {
      final products = _categoryProductsCache[category.name]!;
      return _buildCategoryProductsGrid(products, category);
    }

    // If not cached and not loading, start loading
    if (!_loadingCategoryNames.contains(category.name)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCategoryProductsInline(category.name);
      });
    }

    // Show loading state
    // Show loading state with Shimmer
    return Padding(
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
        itemCount: 4, // Show 4 shimmer cards
        itemBuilder: (context, index) => _buildShimmerProductCard(),
      ),
    );
  }

  Future<void> _loadCategoryProductsInline(String categoryName) async {
    if (_loadingCategoryNames.contains(categoryName)) return;
    if (_categoryProductsCache.containsKey(categoryName)) return;

    try {
      if (mounted) {
        setState(() {
          _loadingCategoryNames.add(categoryName);
        });
      }

      final products =
          await _productService.getProductsByCategory(categoryName);
      if (mounted) {
        setState(() {
          _categoryProductsCache[categoryName] = products;
          _loadingCategoryNames.remove(categoryName);
        });
        print(
            'Category products loaded inline: ${products.length} for $categoryName');
      }
    } catch (e) {
      print('Error loading category products inline: $e');
      if (mounted) {
        setState(() => _loadingCategoryNames.remove(categoryName));
      }
    }
  }

  Widget _buildCategoryProductsGrid(
      List<ProductModel> products, CategoryModel category) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: Color(0xFF4F46E5),
            ),
            const SizedBox(height: 8),
            const Text(
              'No products found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              'No products available in ${category.name} category',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group products by subcategory if available
    final Map<String, List<ProductModel>> subcategoryGroups = {};
    for (final product in products) {
      final subcategory = product.subcategory ?? 'General';
      if (!subcategoryGroups.containsKey(subcategory)) {
        subcategoryGroups[subcategory] = [];
      }
      subcategoryGroups[subcategory]!.add(product);
    }

    // Determine which subcategories to display based on filter
    final filteredGroups = _selectedSubcategoryName != null
        ? Map.fromEntries(
            subcategoryGroups.entries.where((e) => e.key == _selectedSubcategoryName)
          )
        : subcategoryGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Subcategory filter chips (horizontal scroll) ──
        if (subcategoryGroups.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                // "All" chip
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSubcategoryName = null;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedSubcategoryName == null
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedSubcategoryName == null
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedSubcategoryName == null
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _selectedSubcategoryName == null
                                ? Colors.white.withValues(alpha: 0.2)
                                : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${products.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _selectedSubcategoryName == null
                                  ? Colors.white
                                  : const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Individual subcategory chips
                ...subcategoryGroups.entries.map((entry) {
                  final isSelected = _selectedSubcategoryName == entry.key;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSubcategoryName = isSelected ? null : entry.key;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _toTitleCase(entry.key),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${entry.value.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Products grouped by subcategory ──
        ...filteredGroups.entries.map((entry) {
          final subcategoryName = entry.key;
          final subcategoryProducts = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subcategory section header
              if (subcategoryGroups.length > 1 && _selectedSubcategoryName == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _toTitleCase(subcategoryName),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${subcategoryProducts.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Products grid
              Padding(
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
                  itemCount: subcategoryProducts.length,
                  itemBuilder: (context, index) {
                    final product = subcategoryProducts[index];
                    return _buildProductCard(product);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildProductCard(ProductModel product,
      {Color? imageBackgroundColor}) {
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
      imageBackgroundColor: imageBackgroundColor,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      },
      onAddToCart: () {
        final cartService = Provider.of<CartService>(context, listen: false);

        // Stock Check
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
        final cartService =
            Provider.of<QuoteRequestCartService>(context, listen: false);
        cartService.addItem(
          product,
          quantity: 1,
          notes: '',
        );
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

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldCollapse = offset > 50;

    if (shouldCollapse != _isHeaderCollapsed && mounted) {
      setState(() {
        _isHeaderCollapsed = shouldCollapse;
      });
      if (shouldCollapse) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
      }
    }
  }

  // Sync: user swipes content → update selected tab
  void _onPageChanged() {
    if (!_contentPageController.hasClients) return;
    final page = _contentPageController.page?.round() ?? 0;
    if (page != _selectedCategoryIndex && mounted) {
      setState(() {
        _selectedCategoryIndex = page;
      });
    }
  }

  // Sync: user taps tab → animate PageView
  void _onTabTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedCategoryIndex = index;
      });
      if (_contentPageController.hasClients) {
        _contentPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _resetHorizontalScrollPositions() {
    // Reset all horizontal scrollable widgets to their initial positions
    // Use jumpTo for immediate reset without animation
    try {
      if (_categoryScrollController.hasClients) {
        _categoryScrollController.jumpTo(0.0);
      }
      if (_brandScrollController.hasClients) {
        _brandScrollController.jumpTo(0.0);
      }
      if (_brandScrollController2.hasClients) {
        _brandScrollController2.jumpTo(0.0);
      }
      if (_featuredProductsScrollController.hasClients) {
        _featuredProductsScrollController.jumpTo(0.0);
      }
      if (_searchBrandScrollController.hasClients) {
        _searchBrandScrollController.jumpTo(0.0);
      }
      if (_featuredCardsScrollController.hasClients) {
        _featuredCardsScrollController.jumpTo(0.0);
      }
      if (_offerCardsScrollController.hasClients) {
        _offerCardsScrollController.jumpTo(0.0);
      }
      if (_categoryProductsScrollController.hasClients) {
        _categoryProductsScrollController.jumpTo(0.0);
      }
      if (_moreProductsScrollController.hasClients) {
        _moreProductsScrollController.jumpTo(0.0);
      }
      if (_imageSlidesPageController.hasClients && _imageSlides.isNotEmpty) {
        _imageSlidesPageController.jumpToPage(0);
      }
    } catch (e) {
      print('Error resetting scroll positions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    print('Performing search for: "$query"');
    if (query.isEmpty) {
      print('Query is empty, clearing search');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchBrands = [];
          _isSearching = false;
          _showSearchResults = false;
          _currentSearchQuery = '';
        });
      }
      return;
    }

    print('Setting search state...');
    if (mounted) {
      setState(() {
        _isSearching = true;
        _currentSearchQuery = query;
        _showSearchResults = true;
      });
    }

    try {
      // Search products with brands and brands separately
      final results = await Future.wait([
        _productService.searchProductsWithBrands(query),
        _brandService.searchBrands(query),
      ]);

      final products = results[0] as List<ProductModel>;
      final brands = results[1] as List<BrandModel>;

      if (mounted) {
        setState(() {
          _searchResults = products;
          _searchBrands = brands;
          _isSearching = false;
        });

        // Show no results message if needed
        if (products.isEmpty && brands.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No results found for "$query". We can\'t help with that right now.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) {
      setState(() {
        _searchResults = [];
        _searchBrands = [];
        _showSearchResults = false;
        _currentSearchQuery = '';
      });
    }
  }

  // Public method to handle back press from parent
  Future<bool> handleBack() async {
    // If searching, close search results
    if (_isSearching || _showSearchResults) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _showSearchResults = false;
          _searchController.clear();
        });
      }
      return true; // We handled the back press
    }

    // If inside a category tab (not "All"), go back to "All"
    if (_selectedCategoryIndex != 0 || _showCategoryResults) {
      _showAllCategories();
      return true; // We handled the back press
    }

    return false; // We did not handle it
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── 1. Glassmorphic Sticky Header ──
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                    border: const Border(
                      bottom: BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Address bar — hides on scroll
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _isHeaderCollapsed
                            ? const SizedBox(width: double.infinity, height: 0)
                            : _buildCompactAddressBar(),
                      ),
                      // Search bar — always visible
                      _buildSearchBar(),
                      // Category tabs — single unified row, scales on scroll
                      if (!_showSearchResults && !_showCategoryResults)
                        _buildCategoryRow(),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. Swipeable Content Area ──
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    final offset = notification.metrics.pixels;
                    final shouldCollapse = offset > 30;
                    if (shouldCollapse != _isHeaderCollapsed && mounted) {
                      setState(() {
                        _isHeaderCollapsed = shouldCollapse;
                      });
                      if (shouldCollapse) {
                        _fadeController.forward();
                      } else {
                        _fadeController.reverse();
                      }
                    }
                  }
                  return false;
                },
                child: _showSearchResults
                    ? _buildSearchResultsList()
                    : _showCategoryResults
                        ? _buildCategoryResultsList()
                        : PageView.builder(
                            controller: _contentPageController,
                            itemCount: _categories.length + 1,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildAllTabContent();
                              } else {
                                final category = _categories[index - 1];
                                return _buildCategoryTabContent(category);
                              }
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact address bar (smaller, subtle, same content) ──
  Widget _buildCompactAddressBar() {
    if (!_isLoggedIn) {
      return _buildGuestAddressBar();
    }

    return GestureDetector(
      onTap: _showAddressSelector,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
        child: Row(
          children: [
            // Location icon
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF4F46E5),
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            // "Delivering to" + address
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Delivering to',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _userAddress,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey[500],
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Profile & Notification icons (smaller)
            _buildCompactHeaderIcon(
              Icons.person_outline,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ),
            ),
            const SizedBox(width: 6),
            _buildCompactHeaderIcon(
              Icons.notifications_outlined,
              () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationsScreen()),
                );
                // Handle navigation result from notification tap
                if (result != null && mounted) {
                  final type = result['type']?.toString() ?? '';
                  final refId = result['referenceId']?.toString();
                  if (type == 'quotation') {
                    widget.onSwitchToTab?.call(1, quoteId: refId);
                  } else if (type == 'order' || type == 'refund') {
                    widget.onSwitchToTab?.call(3);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeaderIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(icon, color: const Color(0xFF1E293B), size: 18),
      ),
    );
  }

  Widget _buildGuestAddressBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF4F46E5),
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Add delivery address',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[500],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── Scrollable "All" tab content ──
  Widget _buildAllTabContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Hero Banner Carousel ──
          if (_imageSlides.isNotEmpty) ...[
            _buildImageSlidesSection(),
            const SizedBox(height: 20),
          ],

          // ── Shop by Brand ──
          _buildBrandSection(),
          const SizedBox(height: 24),

          // ── Featured Products Grid ──
          _buildFeaturedProductsSection(),

          // ── Footer ──
          const SizedBox(height: 40),
          _buildFooter(),
          const SizedBox(height: 100), // Nav bar clearance
        ],
      ),
    );
  }

  // ── Footer Widget ──
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFF1F5F9).withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/contracto.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'Contracto',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4F46E5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your trusted partner in construction supplies',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© ${DateTime.now().year} Contracto. All rights reserved.',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scrollable category tab content ──
  Widget _buildCategoryTabContent(CategoryModel category) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: _buildCategoryProductsContent(category),
    );
  }

  Widget _buildCategoryProductsContent(CategoryModel category) {
    final totalProducts = _categoryProductsCache.containsKey(category.name)
        ? _categoryProductsCache[category.name]!.length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Category Hero Card ──
        Builder(builder: (context) {
          final products = _categoryProductsCache[category.name] ?? [];
          final subcatCount =
              products.map((p) => p.subcategory ?? 'General').toSet().length;
          final brandCount =
              products.map((p) => p.brandId).whereType<String>().toSet().length;

          return Container(
            width: double.infinity,
            height: 150,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Left text content
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 160, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top: Title + Badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _toTitleCase(category.name),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (totalProducts > 0) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '$totalProducts products',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Bottom: Stats
                        if (totalProducts > 0)
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              if (subcatCount > 1)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.category_outlined,
                                        size: 12, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$subcatCount types',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              if (brandCount > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_outlined,
                                        size: 12, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$brandCount ${brandCount == 1 ? 'brand' : 'brands'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                // Right: 3D Icon — overflows above card
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: _build3DCategoryIcon(category),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        // ── Products ──
        _buildCachedCategoryProducts(category),

        // Bottom spacing
        const SizedBox(height: 80),
      ],
    );
  }

  /// Build a 3D category icon from local assets, falling back to the regular image
  Widget _build3DCategoryIcon(CategoryModel category) {
    final asset3d = _get3DCategoryAsset(category.name);
    if (asset3d != null) {
      return Image.asset(
        asset3d,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildCategoryImage(category),
      );
    }
    return _buildCategoryImage(category);
  }

  /// Map category names to 3D asset paths
  String? _get3DCategoryAsset(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('tool')) return 'assets/images/cat_tools_3d.png';
    if (name.contains('pump')) return 'assets/images/cat_pump_3d.png';
    if (name.contains('plumbing')) return 'assets/images/cat_plumbing_3d.png';
    if (name.contains('electrical'))
      return 'assets/images/cat_electrical_3d.png';
    if (name.contains('cable')) return 'assets/images/cat_cables_3d.png';
    if (name.contains('structural') || name.contains('m.s'))
      return 'assets/images/cat_structural_3d.png';
    if (name.contains('waterproofing'))
      return 'assets/images/cat_waterproofing_3d.png';
    if (name.contains('switch')) return 'assets/images/cat_switches_3d.png';
    if (name.contains('lighting') || name.contains('light'))
      return 'assets/images/cat_lighting_3d.png';
    if (name.contains('hardware')) return 'assets/images/cat_hardware_3d.png';
    if (name.contains('bath') || name.contains('faucet'))
      return 'assets/images/cat_bath_3d.png';
    if (name.contains('building') || name.contains('material'))
      return 'assets/images/cat_building_3d.png';
    if (name.contains('dustbin') || name.contains('bin'))
      return 'assets/images/cat_dustbin_3d.png';
    return null;
  }

  // ── Search results as a scrollable list (not sliver) ──
  Widget _buildSearchResultsList() {
    return CustomScrollView(
      slivers: [
        _buildSearchResultsContent(),
        if (_isSearching)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Searching for "$_currentSearchQuery"...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.70,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) => _buildShimmerProductCard(),
                  ),
                ],
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  // ── Category results as a scrollable list (not sliver) ──
  Widget _buildCategoryResultsList() {
    return CustomScrollView(
      slivers: [
        _buildCategoryResultsContent(),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  void _showAddressSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressSelectorSheet(
        addresses: _userAddresses,
        selectedLabel: _userAddress,
        onSelect: (label) {
          if (mounted) {
            setState(() => _userAddress = label);
          }
        },
        onAddNew: () {
          Navigator.pop(context);
          _showModernAddAddressDialog();
        },
        onDetectLocation: () {
          Navigator.pop(context);
          _detectAndAddAddress();
        },
      ),
    );
  }

  Future<void> _detectAndAddAddress() async {
    final locationService = LocationService();
    try {
      // Show a loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Detecting your location...'),
            ],
          ),
          backgroundColor: Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 10),
        ),
      );

      final location = await locationService.detectCurrentLocation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddressFormSheet(
          prefillStreet: [
            if (location.subLocality != null && location.subLocality!.isNotEmpty)
              location.subLocality!,
            if (location.street != null && location.street!.isNotEmpty)
              location.street!,
          ].join(', '),
          prefillCity: location.city ?? '',
          prefillState: location.state ?? '',
          prefillPincode: location.pincode ?? '',
        ),
      );

      if (result == true && mounted) {
        _loadAddresses();
        _loadUserData();
      }
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect location: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEmptyAddressState() {
    return Center(
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
            child: const Icon(Icons.location_off_rounded,
                size: 32, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Address Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first delivery address',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  IconData _getAddressIcon(String? label) {
    switch (label?.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
        return Icons.business_rounded;
      case 'site':
        return Icons.construction_rounded;
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  void _showModernAddAddressDialog() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddressFormSheet(),
    ).then((saved) {
      if (saved == true && mounted) {
        _loadAddresses();
        _loadUserData();
      }
    });
  }

  Widget _buildGuestHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)], // Deep premium indigo
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to Contracto',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your B2B hardware partner',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.login_rounded,
                      color: Color(0xFF4F46E5),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Login',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Very light soft gray
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _performSearch,
        onChanged: (value) {
          if (value.isEmpty) {
            _clearSearch();
          }
        },
        decoration: InputDecoration(
          hintText: 'Search 5000+ electrical products...',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: GestureDetector(
            onTap: () {
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Icon(Icons.search_rounded,
                  color: Color(0xFF94A3B8), size: 22),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: _showSearchResults
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF94A3B8), size: 20),
                  onPressed: _clearSearch,
                )
              : _isLoggedIn
                  ? GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                              : const Color(0xFF4F46E5).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none_rounded,
                          color: _isListening
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF4F46E5),
                          size: 18,
                        ),
                      ),
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _buildCategoryTabsOnly() {
    if (_loadingCategories) {
      return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6, // Show 6 shimmer cards
          itemBuilder: (context, index) => _buildShimmerCategoryCard(),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          controller: _categoryScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: _categories.length + 1, // +1 for "All" tab
          itemBuilder: (context, index) {
            if (index == 0) {
              // "All" tab
              final isSelected = _selectedCategoryIndex == 0;
              return GestureDetector(
                onTap: _showAllCategories,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              );
            } else {
              // Category tabs
              final category = _categories[index - 1];
              final isSelected = _selectedCategoryIndex == index;
              return GestureDetector(
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCards() {
    if (_loadingCategories) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          itemBuilder: (context, index) => _buildShimmerCategoryCard(),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  // ── Single unified category row — rounded squares that scale on scroll ──
  Widget _buildCategoryRow() {
    if (_loadingCategories) {
      return Container(
        height: 80,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 6,
          itemBuilder: (context, index) => _buildShimmerCategoryCard(),
        ),
      );
    }

    if (_categories.isEmpty) return const SizedBox.shrink();

    final collapsed = _isHeaderCollapsed;
    final double rowHeight = collapsed ? 44.0 : 100.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: rowHeight,
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) => _buildCategoryChip(index, collapsed),
      ),
    );
  }

  Widget _buildCategoryChip(int index, bool collapsed) {
    final isAll = index == 0;
    final isSelected = _selectedCategoryIndex == index;
    final category = isAll ? null : _categories[index - 1];
    final label = isAll ? 'All' : category!.name;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        // If height is small (<60), use compact horizontal layout
        // Otherwise use expanded vertical layout
        final useCompact = availableHeight < 60;

        if (useCompact) {
          return GestureDetector(
            onTap: () => _onTabTapped(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAll)
                    Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color:
                          isSelected ? Colors.white : const Color(0xFF64748B),
                    )
                  else
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: _buildCategoryImage(category!),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }

        // Expanded: vertical icon + label
        // Calculate sizes that fit within available height
        final vertMargin = 4.0; // 2 top + 2 bottom
        final usable = availableHeight - vertMargin;
        final iconBoxSize = (usable * 0.6).clamp(28.0, 56.0);
        final imgSize = (iconBoxSize * 0.7).clamp(20.0, 40.0);
        final textHeight = (usable - iconBoxSize - 3).clamp(14.0, 30.0);

        return GestureDetector(
          onTap: () => _onTabTapped(index),
          child: Container(
            width: 72.0,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: isAll
                        ? (isSelected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFF1F5F9))
                        : (isSelected
                            ? const Color(0xFFEEF2FF)
                            : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(14),
                    border: isAll
                        ? null
                        : Border.all(
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isAll
                        ? Icon(
                            Icons.grid_view_rounded,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF64748B),
                            size: imgSize * 0.6,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: imgSize,
                              height: imgSize,
                              child: _buildCategoryImage(category!),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: textHeight,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF475569),
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Expanded: big circles with labels (shown when not scrolled) ──
  Widget _buildExpandedCategoryRow() {
    if (_loadingCategories) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          itemBuilder: (context, index) => _buildShimmerCategoryCard(),
        ),
      );
    }

    if (_categories.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 110,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) => _buildExpandedCategoryItem(index, 0.0),
      ),
    );
  }

  // ── Collapsed: compact pills (shown when scrolled) ──
  Widget _buildCollapsedCategoryRow() {
    if (_loadingCategories || _categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) => _buildCollapsedCategoryChip(index),
      ),
    );
  }

  Widget _buildExpandedCategoryItem(int index, double collapseRatio) {
    final isAll = index == 0;
    final isSelected = _selectedCategoryIndex == index;
    final category = isAll ? null : _categories[index - 1];

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isAll
                    ? (isSelected
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFF1F5F9))
                    : (isSelected
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF8FAFC)),
                shape: BoxShape.circle,
                border: isAll
                    ? null
                    : Border.all(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: isAll
                  ? Icon(
                      Icons.grid_view_rounded,
                      color:
                          isSelected ? Colors.white : const Color(0xFF64748B),
                      size: 24,
                    )
                  : ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _buildCategoryImage(category!),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 24,
              child: Text(
                isAll ? 'All' : category!.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF475569),
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedCategoryChip(int index) {
    final isAll = index == 0;
    final isSelected = _selectedCategoryIndex == index;
    final category = isAll ? null : _categories[index - 1];
    final label = isAll ? 'All' : category!.name;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAll)
              Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              )
            else
              SizedBox(
                width: 18,
                height: 18,
                child: ClipOval(
                  child: _buildCategoryImage(category!),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              label.length > 12 ? '${label.substring(0, 10)}…' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryResultsContent() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category query display with back button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _showCategoryResults = false;
                        _selectedCategoryName = null;
                        _categoryProducts.clear();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back,
                        color: Colors.grey[600], size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.category, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_selectedCategoryName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Products section
          if (_categoryProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Products (${_categoryProducts.length})',
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.70,
                ),
                itemCount: _categoryProducts.length,
                itemBuilder: (context, index) {
                  final product = _categoryProducts[index];
                  return _buildProductCard(product);
                },
              ),
            ),
          ],

          // Loading indicator
          if (_loadingCategoryNames.contains(_selectedCategoryName))
            Container(
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ),
            ),

          // No results message
          if (_categoryProducts.isEmpty &&
              !_loadingCategoryNames.contains(_selectedCategoryName))
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.category_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No products found in $_selectedCategoryName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try browsing other categories',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // Bottom padding for navigation bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSearchResultsContent() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search query display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          // Brands we deal in section
          if (_searchBrands.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                controller: _searchBrandScrollController,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          if (_searchBrands.isEmpty && _searchResults.isEmpty && !_isSearching)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
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

          const SizedBox(height: 100), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildSearchBrandCard(BrandModel brand) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BrandProductsScreen(brand: brand),
          ),
        );
      },
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
                        child: CustomNetworkImage(
                          imageUrl: brand.logoUrl!,
                          fit: BoxFit.contain,
                          width: 60,
                          height: 60,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.business,
                                color: Colors.grey[400], size: 24),
                          ),
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

  Widget _buildAllCategoriesPage() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildFeaturedCards(),
        const SizedBox(height: 16),
        _buildShopByBrandSection(),
        const SizedBox(height: 16),
        _buildAllCategoriesSection(),
        const SizedBox(height: 16),
        _buildFeaturedProductsSection(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildToolsPage() {
    return Column(
      children: [
        const SizedBox(height: 4),
        _buildCategorySection('Power Tools', _getPowerToolsCategories()),
        _buildCategorySection('Hand Tools', _getHandToolsCategories()),
        _buildCategorySection(
            'Measuring Tools', _getMeasuringToolsCategories()),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAppliancesPage() {
    return Column(
      children: [
        const SizedBox(height: 4),
        _buildCategorySection(
            'Kitchen Appliances', _getKitchenAppliancesCategories()),
        _buildCategorySection(
            'Home Appliances', _getHomeAppliancesCategories()),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildElectronicsPage() {
    return Column(
      children: [
        const SizedBox(height: 4),
        _buildCategorySection('Cables & Wires', _getCablesCategories()),
        _buildCategorySection('Lighting Solutions', _getLightingCategories()),
        _buildCategorySection(
            'Electrical Components', _getElectricalComponentsCategories()),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOffersPage() {
    return Column(
      children: [
        const SizedBox(height: 4),
        _buildOfferCards(),
        _buildCategorySection('Limited Time Offers', _getOfferCategories()),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFeaturedCards() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.none,
      child: ListView(
        controller: _featuredCardsScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        children: [
          _buildFeaturedCard(
            'Free Estimate',
            'Get Your Quote',
            'Get started',
            Colors.orange,
            Icons.calculate_outlined,
          ),
          _buildFeaturedCard(
            'Trending',
            'Smart Electricals',
            'Best deals',
            const Color(0xFF2563EB),
            Icons.trending_up,
          ),
          _buildFeaturedCard(
            'Express',
            'Same Day Delivery',
            'Order now',
            Colors.green,
            Icons.local_shipping_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(String title, String subtitle, String buttonText,
      Color color, IconData icon) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopByBrandSection() {
    print(
        'Building ShopByBrandSection - Loading: $_loadingBrands, Brands count: ${_brands.length}');
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      clipBehavior: Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop by Brand',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AllBrandsScreen()),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios,
                            size: 10, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            clipBehavior: Clip.none,
            child: _loadingBrands
                ? SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: 5,
                      itemBuilder: (context, index) => _buildShimmerBrandCard(),
                    ),
                  )
                : _brands.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No brands available',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 120, // Fixed height for horizontal scroll
                        child: ListView.builder(
                          controller: _brandScrollController2,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          key: const ValueKey('brands_list_2'),
                          itemCount: _brands.length,
                          itemBuilder: (context, index) {
                            final brand = _brands[index];
                            print(
                                'Building brand card: ${brand.name}, catalogUrl: ${brand.catalogUrl}');
                            return Container(
                              width: 100, // Fixed width for each brand card
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              child: _buildBrandCard(brand),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCategoryCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Center(
          child: Container(
            width: 50,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerProductCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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

  Widget _buildShimmerImageSlide() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBrandCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 8),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(BrandModel brand) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BrandProductsScreen(brand: brand),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: brand.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: CustomNetworkImage(
                            imageUrl: brand.logoUrl!,
                            fit: BoxFit.contain,
                            width: 42,
                            height: 42,
                            errorWidget: Icon(Icons.business,
                                color: Colors.grey[400], size: 24),
                          ),
                        ),
                      )
                    : Icon(Icons.business, color: Colors.grey[400], size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                brand.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<CategoryItem> categories) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      clipBehavior: Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: categories.length > 8 ? 8 : categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(categories[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryItem category) {
    return GestureDetector(
      onTap: () {
        // Navigate to category products
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(category.name),
                backgroundColor: category.backgroundColor,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category.icon,
                      size: 64,
                      color: category.backgroundColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Products coming soon...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: category.backgroundColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: category.backgroundColor.withValues(alpha: 0.2)),
            ),
            child: Icon(
              category.icon,
              color: category.backgroundColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCards() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        controller: _offerCardsScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        children: [
          _buildOfferCard('50% OFF', 'Power Tools', 'Limited time', Colors.red),
          _buildOfferCard(
              'Buy 2 Get 1', 'Electrical', 'This week', Colors.green),
          _buildOfferCard('Free Shipping', 'Orders above ₹500', 'Today only',
              Colors.purple),
        ],
      ),
    );
  }

  Widget _buildOfferCard(
      String title, String subtitle, String validity, Color color) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
          const Spacer(),
          Text(
            validity,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  List<CategoryItem> _getHardwareCategories() {
    return [
      CategoryItem(
          name: 'Power Tools',
          icon: Icons.build_circle,
          backgroundColor: Colors.blue),
      CategoryItem(
          name: 'Hand Tools',
          icon: Icons.handyman,
          backgroundColor: Colors.orange),
      CategoryItem(
          name: 'Measuring Tools',
          icon: Icons.straighten,
          backgroundColor: Colors.green),
      CategoryItem(
          name: 'Fasteners',
          icon: Icons.construction,
          backgroundColor: Colors.purple),
      CategoryItem(
          name: 'Safety Gear',
          icon: Icons.security,
          backgroundColor: Colors.red),
      CategoryItem(
          name: 'Cutting Tools',
          icon: Icons.content_cut,
          backgroundColor: Colors.teal),
      CategoryItem(
          name: 'Tool Storage',
          icon: Icons.inventory_2,
          backgroundColor: Colors.indigo),
      CategoryItem(
          name: 'Adhesives',
          icon: Icons.format_color_fill,
          backgroundColor: Colors.brown),
    ];
  }

  List<CategoryItem> _getElectricalCategories() {
    return [
      CategoryItem(
          name: 'Cables & Wires',
          icon: Icons.cable,
          backgroundColor: Colors.blue),
      CategoryItem(
          name: 'LED Lights',
          icon: Icons.lightbulb,
          backgroundColor: Colors.yellow),
      CategoryItem(
          name: 'Fans & Coolers',
          icon: Icons.air,
          backgroundColor: Colors.cyan),
      CategoryItem(
          name: 'Switches',
          icon: Icons.toggle_on,
          backgroundColor: Colors.green),
      CategoryItem(
          name: 'Sockets',
          icon: Icons.electrical_services,
          backgroundColor: Colors.orange),
      CategoryItem(
          name: 'MCB & RCCB',
          icon: Icons.electric_bolt,
          backgroundColor: Colors.red),
      CategoryItem(
          name: 'Inverters',
          icon: Icons.battery_charging_full,
          backgroundColor: Colors.purple),
      CategoryItem(
          name: 'Conduits',
          icon: Icons.linear_scale,
          backgroundColor: Colors.grey),
    ];
  }

  List<CategoryItem> _getPowerToolsCategories() {
    if (_categorySectionCache.containsKey('power_tools')) {
      return _categorySectionCache['power_tools']!;
    }

    final categories = [
      CategoryItem(
          name: 'Drill Machines',
          icon: Icons.build_circle,
          backgroundColor: Colors.blue),
      CategoryItem(
          name: 'Angle Grinders',
          icon: Icons.settings,
          backgroundColor: Colors.orange),
      CategoryItem(
          name: 'Circular Saws',
          icon: Icons.content_cut,
          backgroundColor: Colors.red),
      CategoryItem(
          name: 'Impact Drivers',
          icon: Icons.build,
          backgroundColor: Colors.green),
    ];

    _categorySectionCache['power_tools'] = categories;
    return categories;
  }

  List<CategoryItem> _getHandToolsCategories() {
    if (_categorySectionCache.containsKey('hand_tools')) {
      return _categorySectionCache['hand_tools']!;
    }

    final categories = [
      CategoryItem(
          name: 'Hammers', icon: Icons.handyman, backgroundColor: Colors.brown),
      CategoryItem(
          name: 'Screwdrivers',
          icon: Icons.build,
          backgroundColor: Colors.blue),
      CategoryItem(
          name: 'Pliers',
          icon: Icons.construction,
          backgroundColor: Colors.red),
      CategoryItem(
          name: 'Wrenches',
          icon: Icons.settings,
          backgroundColor: Colors.orange),
    ];

    _categorySectionCache['hand_tools'] = categories;
    return categories;
  }

  List<CategoryItem> _getMeasuringToolsCategories() {
    if (_categorySectionCache.containsKey('measuring_tools')) {
      return _categorySectionCache['measuring_tools']!;
    }

    final categories = [
      CategoryItem(
          name: 'Tape Measures',
          icon: Icons.straighten,
          backgroundColor: Colors.green),
      CategoryItem(
          name: 'Spirit Levels',
          icon: Icons.horizontal_rule,
          backgroundColor: Colors.blue),
      CategoryItem(
          name: 'Calipers',
          icon: Icons.straighten,
          backgroundColor: Colors.purple),
      CategoryItem(
          name: 'Rulers',
          icon: Icons.linear_scale,
          backgroundColor: Colors.orange),
    ];

    _categorySectionCache['measuring_tools'] = categories;
    return categories;
  }

  List<CategoryItem> _getKitchenAppliancesCategories() {
    if (_categorySectionCache.containsKey('kitchen_appliances')) {
      return _categorySectionCache['kitchen_appliances']!;
    }

    final categories = [
      CategoryItem(
          name: 'Mixers', icon: Icons.blender, backgroundColor: Colors.pink),
      CategoryItem(
          name: 'Toasters',
          icon: Icons.kitchen,
          backgroundColor: Colors.orange),
      CategoryItem(
          name: 'Kettles',
          icon: Icons.coffee_maker,
          backgroundColor: Colors.brown),
      CategoryItem(
          name: 'Food Processors',
          icon: Icons.restaurant,
          backgroundColor: Colors.green),
    ];

    _categorySectionCache['kitchen_appliances'] = categories;
    return categories;
  }

  List<CategoryItem> _getHomeAppliancesCategories() {
    if (_categorySectionCache.containsKey('home_appliances')) {
      return _categorySectionCache['home_appliances']!;
    }

    final categories = [
      CategoryItem(
          name: 'Vacuum Cleaners',
          icon: Icons.cleaning_services,
          backgroundColor: Colors.blue),
      CategoryItem(
          name: 'Air Conditioners',
          icon: Icons.ac_unit,
          backgroundColor: Colors.cyan),
      CategoryItem(
          name: 'Water Heaters',
          icon: Icons.hot_tub,
          backgroundColor: Colors.red),
      CategoryItem(
          name: 'Washing Machines',
          icon: Icons.local_laundry_service,
          backgroundColor: Colors.purple),
    ];

    _categorySectionCache['home_appliances'] = categories;
    return categories;
  }

  List<CategoryItem> _getCablesCategories() {
    if (_categorySectionCache.containsKey('cables')) {
      return _categorySectionCache['cables']!;
    }

    final categories = [
      CategoryItem(
          name: 'Power Cables', icon: Icons.cable, backgroundColor: Colors.red),
      CategoryItem(
          name: 'Network Cables',
          icon: Icons.lan,
          backgroundColor: Colors.blue),
      CategoryItem(
          name: 'Audio Cables',
          icon: Icons.audiotrack,
          backgroundColor: Colors.green),
      CategoryItem(
          name: 'HDMI Cables',
          icon: Icons.display_settings,
          backgroundColor: Colors.purple),
    ];

    _categorySectionCache['cables'] = categories;
    return categories;
  }

  List<CategoryItem> _getLightingCategories() {
    if (_categorySectionCache.containsKey('lighting')) {
      return _categorySectionCache['lighting']!;
    }

    final categories = [
      CategoryItem(
          name: 'LED Bulbs',
          icon: Icons.lightbulb,
          backgroundColor: Colors.yellow),
      CategoryItem(
          name: 'Tube Lights',
          icon: Icons.light,
          backgroundColor: Colors.white),
      CategoryItem(
          name: 'Flood Lights',
          icon: Icons.wb_sunny,
          backgroundColor: Colors.orange),
      CategoryItem(
          name: 'Strip Lights',
          icon: Icons.linear_scale,
          backgroundColor: Colors.blue),
    ];

    _categorySectionCache['lighting'] = categories;
    return categories;
  }

  List<CategoryItem> _getElectricalComponentsCategories() {
    if (_categorySectionCache.containsKey('electrical_components')) {
      return _categorySectionCache['electrical_components']!;
    }

    final categories = [
      CategoryItem(
          name: 'Switches',
          icon: Icons.toggle_on,
          backgroundColor: Colors.grey),
      CategoryItem(
          name: 'Plugs',
          icon: Icons.electrical_services,
          backgroundColor: Colors.brown),
      CategoryItem(
          name: 'Fuses',
          icon: Icons.electric_bolt,
          backgroundColor: Colors.red),
      CategoryItem(
          name: 'Relays',
          icon: Icons.settings_input_component,
          backgroundColor: Colors.blue),
    ];

    _categorySectionCache['electrical_components'] = categories;
    return categories;
  }

  List<CategoryItem> _getOfferCategories() {
    if (_categorySectionCache.containsKey('offers')) {
      return _categorySectionCache['offers']!;
    }

    final categories = [
      CategoryItem(
          name: 'Clearance Sale',
          icon: Icons.local_offer,
          backgroundColor: Colors.red),
      CategoryItem(
          name: 'Bundle Deals',
          icon: Icons.card_giftcard,
          backgroundColor: Colors.green),
      CategoryItem(
          name: 'Flash Sale',
          icon: Icons.flash_on,
          backgroundColor: Colors.orange),
      CategoryItem(
          name: 'Special Offers',
          icon: Icons.star,
          backgroundColor: Colors.purple),
    ];

    _categorySectionCache['offers'] = categories;
    return categories;
  }

  Widget _buildAllCategoriesSection() {
    if (_loadingCategories) {
      return SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) => _buildShimmerProductCard(),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllCategoriesScreen(),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _categories.length > 6 ? 6 : _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return GestureDetector(
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _selectedCategoryIndex =
                          index + 1; // +1 because index 0 is "All"
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Category Image
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: category.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CustomNetworkImage(
                                  imageUrl: category.imageUrl!,
                                  fit: BoxFit.contain,
                                  errorWidget: Icon(
                                    _getCategoryIcon(
                                        category.iconName ?? category.name),
                                    size: 20,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                ),
                              )
                            : Icon(
                                _getCategoryIcon(
                                    category.iconName ?? category.name),
                                size: 20,
                                color: const Color(0xFF4F46E5),
                              ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${category.productCount} items',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to all products screen
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView.builder(
              controller: _categoryProductsScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _featuredProducts.length,
              itemBuilder: (context, index) {
                final product = _featuredProducts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailsScreen(product: product),
                      ),
                    );
                  },
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const [
                              Color(0xFFFFFACD),
                              Color(0xFFFF9999),
                              Color(0xFFE6E6FA),
                              Color(0xFFD4F4DD),
                            ][index % 4],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: product.photos.isNotEmpty
                                ? Container(
                                    color: Colors.transparent,
                                    child: CustomNetworkImage(
                                      imageUrl: product.photos.first,
                                      fit: BoxFit.contain,
                                      errorWidget: Image.asset(
                                        'assets/images/contracto.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.transparent,
                                    child: Image.asset(
                                      'assets/images/contracto.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                          ),
                        ),

                        // Product Details
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.productName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (product.category?.isNotEmpty == true)
                                  Text(
                                    product.category!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                const Spacer(),
                                Row(
                                  children: [
                                    if (product.finalPrice != null) ...[
                                      Text(
                                        '₹${product.finalPrice!.round()}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                      if (product.mrp != null &&
                                          product.mrp! >
                                              product.finalPrice!) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${product.mrp!.round()}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ] else if (product.mrp != null) ...[
                                      Text(
                                        '₹${product.mrp!.round()}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Add to cart functionality
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Add to Cart',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Convert any string to Title Case: "FIRE PUMP" → "Fire Pump", "dewatering pump" → "Dewatering Pump"
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  IconData _getCategoryIcon(String categoryNameOrIcon) {
    // Map category names and icon names to Material Icons
    switch (categoryNameOrIcon.toLowerCase()) {
      case 'fresh':
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'snack':
      case 'fastfood':
        return Icons.fastfood;
      case 'oils':
      case 'opacity':
        return Icons.opacity;
      case 'tools':
      case 'build':
        return Icons.build;
      case 'electrical':
      case 'electrical_services':
        return Icons.electrical_services;
      case 'plumbing':
        return Icons.plumbing;
      case 'safety':
      case 'security':
        return Icons.security;
      case 'cleaning':
      case 'cleaning_services':
        return Icons.cleaning_services;
      default:
        return Icons.category;
    }
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
    // Navigate to the unified Product Enquiry screen
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

class CategoryItem {
  final String name;
  final IconData icon;
  final Color backgroundColor;

  CategoryItem({
    required this.name,
    required this.icon,
    required this.backgroundColor,
  });
}

// ═══════════════════════════════════════════════════════
// Address Selector Bottom Sheet (Home Screen)
// ═══════════════════════════════════════════════════════

class _AddressSelectorSheet extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final String selectedLabel;
  final void Function(String) onSelect;
  final VoidCallback onAddNew;
  final VoidCallback onDetectLocation;

  const _AddressSelectorSheet({
    required this.addresses,
    required this.selectedLabel,
    required this.onSelect,
    required this.onAddNew,
    required this.onDetectLocation,
  });

  IconData _getIcon(String? label) {
    switch (label?.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
        return Icons.business_rounded;
      case 'site':
        return Icons.construction_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // GPS auto-detect
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: onDetectLocation,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Current Location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Auto-fill address from GPS',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Saved addresses label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Saved Addresses',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Address list
          Expanded(
            child: addresses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.location_off_rounded,
                              size: 28, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        const Text('No Saved Addresses',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      final label = address['label'] ?? 'Home';
                      final isSelected = selectedLabel == label;

                      return GestureDetector(
                        onTap: () {
                          onSelect(label);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4F46E5).withValues(alpha: 0.04)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getIcon(label),
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      address['address'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    size: 22, color: Color(0xFF4F46E5)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Add new address button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: GestureDetector(
              onTap: onAddNew,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_location_alt_rounded,
                        size: 18, color: Color(0xFF4F46E5)),
                    SizedBox(width: 8),
                    Text(
                      'Add New Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
