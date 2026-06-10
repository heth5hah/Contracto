import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/features/products/data/services/product_service.dart';
import 'package:contracto_app/features/quotations/presentation/screens/quote_request_cart_screen.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';
import 'package:contracto_app/shared/widgets/cart_notification.dart';
import 'package:contracto_app/features/quotations/data/services/quote_request_cart_service.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/auth/presentation/screens/login_screen.dart';
import 'package:contracto_app/features/brands/data/services/brand_service.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/brands/presentation/screens/brand_catalog_pdf_screen.dart';
import 'package:contracto_app/features/auth/data/services/user_service.dart';
import 'package:contracto_app/shared/widgets/bulk_discount_badge.dart' as widgets;
import 'package:contracto_app/features/wishlist/data/services/wishlist_service.dart';
import 'package:contracto_app/features/products/data/services/unit_service.dart';
import 'package:provider/provider.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  double _quantity = 1.0; // Changed to double for decimal support
  bool _isInWishlist = false;
  bool _isAddingToCart = false;
  bool _isRequestingQuote = false;
  final Map<String, double> _qualityOptionQuantities = {}; // Changed to double
  final Map<String, TextEditingController> _qualityControllers = {}; // Controllers for manual input
  final CartService _cartService = CartService();
  final BrandService _brandService = BrandService();
  final WishlistService _wishlistService = WishlistService();
  final UnitService _unitService = UnitService();
  final UserService _userService = UserService();
  final ProductService _productService = ProductService();

  Map<String, int> _inventoryStock = {};
  bool _isLoadingInventory = false;
  late ProductModel _currentProduct;
  RealtimeChannel? _inventorySubscription;
  RealtimeChannel? _productSubscription;

  // Note functionality
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');

  // Unit selection
  List<UnitModel> _availableUnits = [];
  UnitModel? _selectedUnit;
  // Map to store selected unit for each quality option
  final Map<String, UnitModel> _qualityOptionUnits = {};
  bool _isLoadingUnits = false;

  // Brand information
  List<BrandModel> _brands = [];
  bool _isLoadingBrand = false;
  Set<String> _selectedBrandIds = {}; // Track selected brands

  // Check if product requires quote instead of direct purchase
  // Only products with NO price require a quote request
  bool get _needsQuoteRequest {
    return (widget.product.finalPrice ?? widget.product.mrp ?? 0) == 0;
  }

  // Check if product can be added to cart
  bool get _canAddToCart {
    return !_needsQuoteRequest;
  }

  // Base unit price for single-price products (used for delivery calculation)
  double get _unitPrice {
    if (widget.product.hasQualityOptions) return 0;
    return (widget.product.finalPrice ?? widget.product.mrp ?? 0).toDouble();
  }

  // Helper method to handle wishlist authentication
  void _handleWishlistAction() async {
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to manage wishlist'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to login screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
      return;
    }

    // User is authenticated, proceed with wishlist action
    if (_isInWishlist) {
      // Remove from wishlist
      final success = await _wishlistService.removeFromWishlistByProductId(widget.product.id);
      if (success && mounted) {
        setState(() => _isInWishlist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from wishlist'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Add to wishlist
      final success = await _wishlistService.addToWishlist(widget.product.id);
      if (success && mounted) {
        setState(() => _isInWishlist = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to wishlist'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize quantities for quality options to 0 (not selected)
    if (widget.product.hasQualityOptions) {
      for (final option in widget.product.qualityOptions) {
        _qualityOptionQuantities[option.id] = 0.0;
        _qualityControllers[option.id] = TextEditingController(text: '0');
      }
    }
    _currentProduct = widget.product;
    // Load brand information if product has a brand
    _loadBrandInfo();
    // Check if product is in wishlist
    _checkWishlistStatus();
    // Load available units for this product
    _loadUnits();
    // Load inventory stock levels
    _loadInventory();
    // Subscribe to product changes
    _subscribeToProductChanges();
  }

  @override
  void dispose() {
    _inventorySubscription?.unsubscribe();
    _productSubscription?.unsubscribe();
    _notesController.dispose();
    _quantityController.dispose();
    for (var controller in _qualityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInventory() async {
    if (!mounted) return;
    setState(() => _isLoadingInventory = true);
    try {
      final stock = await _productService.getProductInventory(_currentProduct.id);
      if (mounted) {
        setState(() {
          _inventoryStock = stock;
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      print('Error loading inventory: $e');
      if (mounted) setState(() => _isLoadingInventory = false);
    }

    // Subscribe to real-time inventory changes
    _inventorySubscription?.unsubscribe();
    _inventorySubscription = SupabaseService.client
        .channel('inventory_product_${_currentProduct.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'product_id',
            value: _currentProduct.id,
          ),
          callback: (payload) {
            _reloadInventoryQuietly();
          },
        )
        .subscribe();
  }

  Future<void> _reloadInventoryQuietly() async {
    try {
      final stock = await _productService.getProductInventory(_currentProduct.id);
      if (mounted) {
        setState(() {
          _inventoryStock = stock;
        });
      }
    } catch (e) {
      print('Error reloading inventory quietly: $e');
    }
  }

  void _subscribeToProductChanges() {
    _productSubscription?.unsubscribe();
    _productSubscription = SupabaseService.client
        .channel('product_detail_${_currentProduct.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _currentProduct.id,
          ),
          callback: (payload) async {
            // Reload product data to get fresh immutable model
            final updatedProduct = await _productService.getProductById(_currentProduct.id);
            if (updatedProduct != null && mounted) {
              setState(() {
                _currentProduct = updatedProduct;
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoadingUnits = true);
    try {
      final units = await _unitService.getUnits();
      if (mounted) {
        setState(() {
          _availableUnits = units;
          
          // Determine the appropriate default unit based on product category
          // Categories that should use 'Pcs' (Pieces) instead of 'Kg'
          final pieceBasedCategories = [
            'bath & faucet', 'bathroom', 'faucet', 'plumbing', 'electrical',
            'switches', 'lighting', 'hardware', 'tools', 'accessories',
            'fittings', 'valves', 'pipes', 'sanitary', 'sanitaryware',
            'tiles', 'doors', 'windows', 'locks', 'handles', 'appliances',
          ];
          
          final productCategory = _currentProduct.category?.toLowerCase().trim() ?? '';
          final shouldUsePieces = pieceBasedCategories.any((cat) => productCategory.contains(cat));
          
          if (units.isNotEmpty) {
            if (shouldUsePieces) {
              // For piece-based categories, try to find 'Pcs' unit first
              _selectedUnit = units.firstWhere(
                (u) => u.code.toLowerCase() == 'pcs' || u.name.toLowerCase() == 'piece',
                orElse: () => units.first,
              );
            } else if (_currentProduct.unit != null) {
              // Try to find exact match based on product's unit (case-insensitive)
              final productUnit = _currentProduct.unit!.toLowerCase().trim();
              _selectedUnit = units.firstWhere(
                (u) => u.code.toLowerCase().trim() == productUnit || 
                       u.name.toLowerCase().trim() == productUnit,
                orElse: () => units.first,
              );
            } else {
              // Default to first unit (which is now 'Pcs' based on earlier change)
              _selectedUnit = units.first;
            }
          } else {
            _selectedUnit = null;
          }

          // Initialize unit for all quality options
          if (_currentProduct.hasQualityOptions && _selectedUnit != null) {
            for (var option in _currentProduct.qualityOptions) {
              _qualityOptionUnits[option.id] = _selectedUnit!;
            }
          }

          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      print('Error loading units: $e');
      if (mounted) {
        setState(() => _isLoadingUnits = false);
      }
    }
  }

  Future<void> _checkWishlistStatus() async {
    if (SupabaseService.instance.isAuthenticated) {
      final isInWishlist = await _wishlistService.isInWishlist(_currentProduct.id);
      if (mounted) {
        setState(() => _isInWishlist = isInWishlist);
      }
    }
  }

  Future<void> _loadBrandInfo() async {
    // Load brands from brandIds if available, otherwise fallback to brandId
    final List<String> brandIds = _currentProduct.brandIds.isNotEmpty
        ? _currentProduct.brandIds
        : (_currentProduct.brandId != null
            ? [_currentProduct.brandId!]
            : <String>[]);

    if (brandIds.isNotEmpty) {
      setState(() => _isLoadingBrand = true);
      try {
        final brands = await _brandService.getBrandsByIds(brandIds);
        if (mounted) {
          setState(() {
            _brands = brands;
            _isLoadingBrand = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingBrand = false);
        }
      }
    }
  }


  void _addToCart() async {
    // Check if product can be added to cart (has pricing)
    if (!_canAddToCart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This product requires a quote request. Please use "Request Quote" instead.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if user is authenticated
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add items to cart'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to login screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
      return;
    }

    if (_currentProduct.hasQualityOptions &&
        !_qualityOptionQuantities.values.any((qty) => qty > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select at least one quality option with quantity'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
    }
    
    // Check Stock Availability
    if (_currentProduct.stockStatus == 'out_of_stock' || (_currentProduct.stockQuantity != null && _currentProduct.stockQuantity == 0)) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is currently out of stock'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Check variant stock
    if (_currentProduct.hasQualityOptions) {
      for (final option in _currentProduct.qualityOptions) {
        final requestedQty = _qualityOptionQuantities[option.id] ?? 0;
        if (requestedQty > 0) {
          final stock = _inventoryStock[option.name] ?? -1;
          if (stock >= 0 && requestedQty > stock) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Only $stock available for ${option.name}'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
            return;
          }
        }
      }
    } else if (_currentProduct.stockQuantity != null && _quantity > _currentProduct.stockQuantity!) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${_currentProduct.stockQuantity} available in stock'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Calculate total requested quantity
    double totalRequestedQty = 0;
    if (_currentProduct.hasQualityOptions) {
      totalRequestedQty = _qualityOptionQuantities.values.fold(0, (sum, qty) => sum + qty);
    } else {
      totalRequestedQty = _quantity;
    }

    // Check against Stock Quantity if defined
    if (_currentProduct.stockQuantity != null) {
      // Get quantity already in cart
      final cartItems = _cartService.cartItems.where((i) => i.product.id == _currentProduct.id);
      final double currentCartQty = cartItems.fold(0, (sum, i) => sum + i.quantity);
      
      final double totalQty = currentCartQty + totalRequestedQty;
      
      if (totalQty > _currentProduct.stockQuantity!) {
        final double available = _currentProduct.stockQuantity! - currentCartQty;
        String msg;
        if (available <= 0) {
           msg = 'You already have all available stock in your cart.';
        } else {
           msg = 'Only ${available.toInt()} more items available in stock.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _isAddingToCart = true);

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      setState(() => _isAddingToCart = false);

        if (_currentProduct.hasQualityOptions) {
          for (final entry in _qualityOptionQuantities.entries) {
            if (entry.value > 0) {
              final qualityOption = _currentProduct.qualityOptions
                  .firstWhere((option) => option.id == entry.key);
              
              // Use the unit selected for this specific quality option
              final unit = _qualityOptionUnits[entry.key]?.code ?? _selectedUnit?.code;
              
              _cartService.addToCart(
                widget.product,
                entry.value,
                qualityOption: qualityOption,
                unit: unit,
              );
            }
          }
        } else {
        _cartService.addToCart(
          widget.product,
          _quantity,
          unit: _selectedUnit?.code,
        );
      }

          CartNotification.show(
            context,
            productName: _currentProduct.productName,
            onViewCart: () {
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/main', arguments: 2);
            },
          );
    }
  }


  void _openBrandCatalog(BrandModel brand) {
    // Check if catalog URL exists and is not empty
    if (brand.catalogUrl != null && brand.catalogUrl!.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BrandCatalogPdfScreen(brand: brand),
        ),
      );
    } else {
      // Show message that catalog is not available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catalog is not available for ${brand.name}'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _requestQuote() async {
    // Check if user is authenticated
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to request quotes'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to login screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
      return;
    }

    // Check if user is blocked
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser != null) {
        final userData = await _userService.getUserByEmail(currentUser.email!);
        if (userData != null && userData.status == 'blocked') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been blocked. You cannot request quotes.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    } catch (e) {
      print('Error checking user status: $e');
    }

    if (_currentProduct.hasQualityOptions &&
        !_qualityOptionQuantities.values.any((qty) => qty > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select at least one quality option with quantity'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // If product has multiple brands, check if any are selected
    if (_brands.length > 1) {
      if (_selectedBrandIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one brand for quote request'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Add quote request for selected brands
      bool anyAdded = false;
      for (final brand in _brands) {
        if (_selectedBrandIds.contains(brand.id)) {
          final success = _addToQuoteRequestCart(
            brandId: brand.id,
            brandName: brand.name,
          );
          if (success) anyAdded = true;
        }
      }
      
      if (anyAdded) {
        _showSuccessDialog();
      }
      return;
    }

    // Proceed with quote request (single brand or no brand)
    try {
      final success = _addToQuoteRequestCart(
        brandId: _brands.isNotEmpty ? _brands.first.id : null,
        brandName: _brands.isNotEmpty ? _brands.first.name : null,
      );
      if (success) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        SupabaseService.handleServiceError(context, e);
      }
    }
  }

  void _showBrandSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Brand(s)'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This product is available from multiple brands. Please select the brand(s) you want to request quotes for:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _brands.length,
                    itemBuilder: (context, index) {
                      final brand = _brands[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: brand.logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CustomNetworkImage(
                                    imageUrl: brand.logoUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.business,
                                          size: 20),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.business, size: 20),
                                ),
                          title: Text(
                            brand.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: brand.description != null
                              ? Text(
                                  brand.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _addToQuoteRequestCart(
                                brandId: brand.id,
                                brandName: brand.name,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Select'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Add quote request for all brands
                bool anyAdded = false;
                for (final brand in _brands) {
                  final success = _addToQuoteRequestCart(
                    brandId: brand.id,
                    brandName: brand.name,
                  );
                  if (success) anyAdded = true;
                }
                if (anyAdded) {
                  _showSuccessDialog();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Request All Brands'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Added!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Product added to quote request cart. Go to Quotes tab to submit your request.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Shopping'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuoteRequestCartScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('View Quote Cart'),
          ),
        ],
      ),
    );
  }

  bool _addToQuoteRequestCart({String? brandId, String? brandName}) {
    // Validate quantity
    final quantityText = _quantityController.text.trim();
    final parsedQuantity = double.tryParse(quantityText);
    if (parsedQuantity == null || parsedQuantity <= 0) {
      if (!_currentProduct.hasQualityOptions) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid quantity greater than 0'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    
    // Validate unit selection
    if (_selectedUnit == null && _availableUnits.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a unit'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    try {
      final quoteRequestCart =
          Provider.of<QuoteRequestCartService>(context, listen: false);

      final unitCode = _selectedUnit?.code ?? 'Pcs';
      final unitName = _selectedUnit?.name ?? 'Piece';

      if (_currentProduct.hasQualityOptions) {
        // Add quality options with quantities to quote request cart
        for (final entry in _qualityOptionQuantities.entries) {
          if (entry.value > 0) {
            final qualityOption = _currentProduct.qualityOptions
                .firstWhere((option) => option.id == entry.key);
            
            // Get specific unit for this option
            final optionUnit = _qualityOptionUnits[entry.key] ?? _selectedUnit;
            final optionUnitCode = optionUnit?.code ?? 'Pcs';
            final optionUnitName = optionUnit?.name ?? 'Piece';

            quoteRequestCart.addItem(
              widget.product,
              quantity: entry.value,
              qualityOptionId: qualityOption.id,
              qualityOptionName: qualityOption.name,
              notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
              brandId: brandId,
              brandName: brandName,
              unit: optionUnitCode,
              unitName: optionUnitName,
              replaceQuantity: true,
            );
          }
        }
      } else {
        // Single product quote request
        if (parsedQuantity != null && parsedQuantity > 0) {
          quoteRequestCart.addItem(
            widget.product,
            quantity: parsedQuantity,
            notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
            brandId: brandId,
            brandName: brandName,
            unit: unitCode,
            unitName: unitName,
            replaceQuantity: true,
          );
        }
      }
      return true;
    } catch (e) {
      print('Error adding to quote request cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Widget _buildQualityOptionChip(QualityOption option) {
    final bool isSelected = _qualityOptionQuantities[option.id]! > 0;
    final price = option.finalPrice ?? option.mrp ?? 0;
    final quantity = _qualityOptionQuantities[option.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
        border: Border.all(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quality option header
          Row(
            children: [
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              if (isSelected) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price > 0
                          ? '${option.name} - ₹${price.round()} / ${_selectedUnit?.code ?? 'Pcs'}'
                          : option.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF3B82B6)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    if (!_isLoadingInventory) ...[
                      const SizedBox(height: 2),
                      _buildStockBadge(option.name),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quantity selector
          Wrap(
            spacing: 8,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quantity:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 32,
                    child: TextField(
                      controller: _qualityControllers[option.id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0, // Centered vertically
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: quantity > 0
                            ? const Color(0xFF1E293B)
                            : Colors.grey[400],
                      ),
                      onChanged: (value) {
                         double val = double.tryParse(value) ?? 0.0;
                         final stock = _inventoryStock[option.name] ?? -1;
                         
                         if (stock >= 0 && val > stock) {
                           // Show notification and cap value
                           ScaffoldMessenger.of(context).hideCurrentSnackBar();
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                               content: Text('Only $stock available for ${option.name}'),
                               backgroundColor: const Color(0xFFF59E0B),
                               behavior: SnackBarBehavior.floating,
                               duration: const Duration(seconds: 2),
                             ),
                           );
                           
                           val = stock.toDouble();
                           _qualityControllers[option.id]?.text = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1);
                           _qualityControllers[option.id]?.selection = TextSelection.fromPosition(
                             TextPosition(offset: _qualityControllers[option.id]!.text.length),
                           );
                         }
                         
                         setState(() {
                           _qualityOptionQuantities[option.id] = val;
                         });
                      },
                    ),
                  ),
                ],
              ),
              
              // Unit Selector for this option
              if (_availableUnits.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unit:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<UnitModel>(
                          value: _qualityOptionUnits[option.id] ?? _selectedUnit,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          onChanged: (UnitModel? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _qualityOptionUnits[option.id] = newValue;
                              });
                            }
                          },
                          items: _availableUnits.map((UnitModel unit) {
                            return DropdownMenuItem<UnitModel>(
                              value: unit,
                              child: Text(unit.code),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(String optionName) {
    final stock = _inventoryStock[optionName];
    if (stock == null) return const SizedBox.shrink();

    if (stock <= 0) {
      return const Text(
        'Out of Stock',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEF4444),
        ),
      );
    }

    if (stock <= 5) {
      return Text(
        'Only $stock left!',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF59E0B),
        ),
      );
    }

    return Text(
      '$stock available',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF10B981),
      ),
    );
  }

  /// Delivery info shown under the price for single-price products.
  /// If the current order amount (price * quantity) is below 1000,
  /// we show "Delivery: ₹100"; otherwise we show "Free delivery".
  Widget _buildDeliveryInfo() {
    if (_unitPrice <= 0) return const SizedBox.shrink();

    final qtyText = _quantityController.text.trim();
    var quantity = double.tryParse(qtyText) ?? 1.0;
    if (quantity <= 0) quantity = 1.0;

    final orderAmount = _unitPrice * quantity;
    final bool isFree = orderAmount >= 1000;

    final Color bgColor = isFree
        ? const Color(0xFFE0F2FE) // light blue
        : const Color(0xFFF1F5F9); // slate 100
    final Color textColor = isFree
        ? const Color(0xFF0369A1)
        : const Color(0xFF475569); // slate 600

    final String label = isFree ? 'Free delivery' : 'Delivery: ₹100';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withValues(alpha: 0.9), // Slate 100
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isInWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isInWishlist ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                size: 18,
              ),
            ),
            onPressed: _handleWishlistAction,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share_rounded, color: Color(0xFF64748B), size: 18),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            // Top safe area spacing for extended body
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),

            // Product Image with glass card
            Container(
              height: 300,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _currentProduct.photos.isNotEmpty
                  ? PageView.builder(
                      itemCount: _currentProduct.photos.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CustomNetworkImage(
                              imageUrl: _currentProduct.photos[index],
                              fit: BoxFit.contain,
                              errorWidget: Image.asset(
                                'assets/images/contracto.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        'assets/images/contracto.png',
                        fit: BoxFit.contain,
                      ),
                    ),
            ),

            // Product Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Tag
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentProduct.category ?? 'Uncategorized',
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Product Name
                  Text(
                    _currentProduct.productName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Product ID
                  Text(
                    'Product ID: ${_currentProduct.productId}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Transport Charges Section
                  if (_currentProduct.transportCharges > 0) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF), // Indigo 50
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: Color(0xFF4F46E5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Transport Charges',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3730A3), // Indigo 800
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Estimated: ₹${_currentProduct.transportCharges.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF312E81), // Indigo 900
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Price Section - Enhanced Design
                  if (_currentProduct.hasPricing) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentProduct.hasQualityOptions &&
                              _currentProduct.qualityOptions.isNotEmpty) ...[
                            const Text(
                              'Select Quality Options:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the + button to select options and set quantities',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              children: _currentProduct.qualityOptions
                                  .map((option) =>
                                      _buildQualityOptionChip(option))
                                  .toList(),
                            ),
                            if (_qualityOptionQuantities.values
                                .any((qty) => qty > 0)) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF3B82F6)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF3B82F6),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_qualityOptionQuantities.values.where((qty) => qty > 0).length} option${_qualityOptionQuantities.values.where((qty) => qty > 0).length == 1 ? '' : 's'} selected',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF), // Indigo 50
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFF4F46E5), // Indigo 600
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Please select quality options and quantities',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF3730A3), // Indigo 800
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ] else ...[
                            // Single Price Display
                            if ((_currentProduct.finalPrice?.round() ??
                                    _currentProduct.mrp?.round() ??
                                    0) >
                                0) ...[
                              Row(
                                children: [
                                  Text(
                                    '₹${(_currentProduct.finalPrice?.round() ?? _currentProduct.mrp?.round() ?? 0)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                  // Show selected unit next to price
                                  if (_selectedUnit != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '/ ${_selectedUnit!.code.toUpperCase()}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  if (_currentProduct.mrp != null &&
                                      _currentProduct.finalPrice != null &&
                                      _currentProduct.mrp! >
                                          _currentProduct.finalPrice!) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '₹${_currentProduct.mrp!.round()}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        decoration: TextDecoration.lineThrough,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'SALE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              // Delivery charges info below the price
                              _buildDeliveryInfo(),
                              const SizedBox(height: 12),
                              if (!_currentProduct.hasQualityOptions)
                                _buildSingleProductQuantitySelector(),
                            ] else ...[
                              // Price on request message
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFF4F46E5),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Price available on request',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF3730A3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
// Removed redundant "Per pc" text
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // No Price Available
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF4F46E5),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Price available on request',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3730A3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],


                  // Brand Information Section
                  if (_isLoadingBrand || _brands.isNotEmpty)
                    Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
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
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.business_rounded,
                                color: Color(0xFF4F46E5),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Brand Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingBrand) ...[
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Loading brand information...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ] else if (_brands.isNotEmpty) ...[
                          // Multiple brands or single brand display
                          if (_brands.length > 1) ...[
                            // Multiple brands - show selection
                            const SizedBox(height: 8),
                            Text(
                              'Select Brand(s) for Quote Request:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        if (_selectedBrandIds.length ==
                                            _brands.length) {
                                          _selectedBrandIds.clear();
                                        } else {
                                          _selectedBrandIds =
                                              _brands.map((b) => b.id).toSet();
                                        }
                                      });
                                    },
                                    child: Text(
                                      _selectedBrandIds.length == _brands.length
                                          ? 'Deselect All'
                                          : 'Select All',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedBrandIds.clear();
                                      });
                                    },
                                    child: const Text(
                                      'Clear Selection',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          ...(_brands
                              .map((brand) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        // Add checkbox for multi-brand products
                                        if (_brands.length > 1) ...[
                                          Checkbox(
                                            value: _selectedBrandIds
                                                .contains(brand.id),
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedBrandIds
                                                      .add(brand.id);
                                                } else {
                                                  _selectedBrandIds
                                                      .remove(brand.id);
                                                }
                                              });
                                            },
                                            activeColor:
                                                const Color(0xFF3B82F6),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (brand.logoUrl != null) ...[
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFE2E8F0)),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: CustomNetworkImage(
                                                  imageUrl: brand.logoUrl!,
                                                  fit: BoxFit.contain,
                                                  width: 40,
                                                  height: 40,
                                                  errorWidget: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[100],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.business,
                                                      color: Colors.grey[400],
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                brand.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              if (brand.description !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  brand.description!,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _openBrandCatalog(brand),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            elevation: 0,
                                          ),
                                          icon: Icon(
                                            brand.catalogUrl != null
                                                ? Icons.picture_as_pdf
                                                : Icons.inventory_2,
                                            size: 16,
                                          ),
                                          label: Text(
                                            brand.catalogUrl != null
                                                ? 'PDF'
                                                : 'Products',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList()),
                          ],
                      ],
                    ),
                  ),

                  // Bulk Discounts Section
                  if (_currentProduct.hasBulkDiscounts) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: widgets.BulkDiscountList(
                        rules: _currentProduct.bulkDiscountRules
                            .map((rule) => widgets.BulkDiscountRule(
                                  minQuantity: rule.minQuantity,
                                  discountPercent: rule.discountPercent,
                                ))
                            .toList(),
                      ),
                    ),
                  ],

                  // Return Policy Info
                  if (!_currentProduct.isReturnable) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_return_outlined,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Non-Returnable',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'This product cannot be returned after purchase',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Notes Section
                  const SizedBox(height: 16),
                  const Text(
                    'Add Note (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Add any special requirements or notes...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Compact Quantity Selector
              if (!_currentProduct.hasQualityOptions) ...[
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                        icon: const Icon(Icons.remove, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() {
                              _quantity--;
                              _quantityController.text = _quantity.toString();
                            });
                          }
                        },
                      ),
                      SizedBox(
                        width: 36,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: InputBorder.none, 
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          onChanged: (value) {
                            double val = double.tryParse(value) ?? 1.0;
                            if (_currentProduct.stockQuantity != null && val > _currentProduct.stockQuantity!) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Only ${_currentProduct.stockQuantity} available in stock'),
                                  backgroundColor: const Color(0xFFF59E0B),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              val = _currentProduct.stockQuantity!.toDouble();
                              _quantityController.text = val.toString();
                            }
                            setState(() { _quantity = val; });
                          },
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          setState(() {
                            _quantity++;
                            _quantityController.text = _quantity.toString();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Dynamic Action Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_currentProduct.stockStatus == 'out_of_stock' || (_currentProduct.stockQuantity != null && _currentProduct.stockQuantity == 0)) 
                      ? null 
                      : _needsQuoteRequest
                      ? (_isRequestingQuote ||
                              (_currentProduct.hasQualityOptions &&
                                  !_qualityOptionQuantities.values
                                      .any((qty) => qty > 0))
                          ? null
                          : _requestQuote)
                      : (_isAddingToCart ||
                              (_currentProduct.hasQualityOptions &&
                                  !_qualityOptionQuantities.values
                                      .any((qty) => qty > 0))
                          ? null
                          : _addToCart),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_currentProduct.stockStatus == 'out_of_stock' || (_currentProduct.stockQuantity != null && _currentProduct.stockQuantity == 0) || (_currentProduct.hasQualityOptions && _inventoryStock.isNotEmpty && _currentProduct.qualityOptions.every((opt) => (_inventoryStock[opt.name] ?? 0) <= 0)))
                        ? Colors.grey[400]
                        : _needsQuoteRequest
                        ? (_currentProduct.hasQualityOptions &&
                                !_qualityOptionQuantities.values
                                    .any((qty) => qty > 0)
                            ? Colors.grey[400]
                            : const Color(0xFF4F46E5))
                        : (_currentProduct.hasQualityOptions &&
                                !_qualityOptionQuantities.values
                                    .any((qty) => qty > 0)
                            ? Colors.grey[400]
                            : const Color(0xFF4F46E5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: (_currentProduct.stockStatus == 'out_of_stock' || (_currentProduct.stockQuantity != null && _currentProduct.stockQuantity == 0) || (_currentProduct.hasQualityOptions && _inventoryStock.isNotEmpty && _currentProduct.qualityOptions.every((opt) => (_inventoryStock[opt.name] ?? 0) <= 0)))
                      ? const Icon(Icons.remove_shopping_cart, size: 20, color: Colors.white)
                      : _needsQuoteRequest
                      ? (_isRequestingQuote
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.request_quote, size: 20))
                      : (_isAddingToCart
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.shopping_cart, size: 20)),
                  label: Text(
                    (_currentProduct.stockStatus == 'out_of_stock' || (_currentProduct.stockQuantity != null && _currentProduct.stockQuantity == 0) || (_currentProduct.hasQualityOptions && _inventoryStock.isNotEmpty && _currentProduct.qualityOptions.every((opt) => (_inventoryStock[opt.name] ?? 0) <= 0)))
                        ? 'Out of Stock'
                        : _needsQuoteRequest
                        ? (_isRequestingQuote
                            ? 'Requesting...'
                            : (_currentProduct.hasQualityOptions &&
                                    !_qualityOptionQuantities.values
                                        .any((qty) => qty > 0)
                                ? 'Select Options First'
                                : 'Request Quote'))
                        : (_isAddingToCart
                            ? 'Adding...'
                            : (_currentProduct.hasQualityOptions &&
                                    !_qualityOptionQuantities.values
                                        .any((qty) => qty > 0)
                                ? 'Select Options First'
                                : 'Add to Cart')),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSingleProductQuantitySelector() {
    if (_availableUnits.isEmpty && _currentProduct.stockQuantity == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Stock Status
          if (_currentProduct.stockQuantity != null)
            Row(
              children: [
                Icon(
                  _currentProduct.stockQuantity! <= 0 
                      ? Icons.error_outline 
                      : Icons.inventory_2_outlined,
                  size: 16,
                  color: _currentProduct.stockQuantity! <= 0 
                      ? const Color(0xFFEF4444) 
                      : (_currentProduct.stockQuantity! <= 5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                ),
                const SizedBox(width: 6),
                Text(
                  _currentProduct.stockQuantity! <= 0 
                      ? 'Out of Stock' 
                      : (_currentProduct.stockQuantity! <= 5 ? 'Only ${_currentProduct.stockQuantity} left!' : '${_currentProduct.stockQuantity} in stock'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _currentProduct.stockQuantity! <= 0 
                        ? const Color(0xFFEF4444) 
                        : (_currentProduct.stockQuantity! <= 5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                  ),
                ),
              ],
            )
          else
            const SizedBox(),

          // Unit Dropdown
          if (_availableUnits.isNotEmpty)
            Row(
              children: [
                const Text(
                  'Unit: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UnitModel>(
                      value: _selectedUnit,
                      icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                      onChanged: (UnitModel? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedUnit = newValue;
                          });
                        }
                      },
                      items: _availableUnits.map((UnitModel unit) {
                        return DropdownMenuItem<UnitModel>(
                          value: unit,
                          child: Text(unit.name),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }


}
