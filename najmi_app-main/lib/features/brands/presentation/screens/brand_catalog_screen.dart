import 'package:flutter/material.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/features/products/data/services/product_service.dart';
import 'package:contracto_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:contracto_app/features/products/presentation/screens/product_enquiry_screen.dart';
import 'package:contracto_app/shared/widgets/standard_product_card.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';

class BrandCatalogScreen extends StatefulWidget {
  final BrandModel brand;

  const BrandCatalogScreen({
    super.key,
    required this.brand,
  });

  @override
  State<BrandCatalogScreen> createState() => _BrandCatalogScreenState();
}

class _BrandCatalogScreenState extends State<BrandCatalogScreen> {
  bool _isLoading = true;
  List<ProductModel> _products = [];
  final _productService = ProductService();

  Map<String, List<ProductModel>> _productsByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products =
          await _productService.getProductsByBrand(widget.brand.id);
      setState(() {
        _products = products;
        _organizeProductsByCategory();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _organizeProductsByCategory() {
    final organized = <String, List<ProductModel>>{};

    for (final product in _products) {
      final category = product.category ?? 'Uncategorized';
      if (!organized.containsKey(category)) {
        organized[category] = [];
      }
      organized[category]!.add(product);
    }

    _productsByCategory = organized;
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
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: widget.brand.logoUrl != null
                  ? ClipOval(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.network(
                          widget.brand.logoUrl!,
                          fit: BoxFit.contain,
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.business,
                                  color: Colors.grey[400], size: 20),
                            );
                          },
                        ),
                      ),
                    )
                  : Icon(Icons.business, color: Colors.grey[400], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.brand.name} Catalog',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${_products.length} Products',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[700]),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No products found for ${widget.brand.name}',
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
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _productsByCategory.length,
                        itemBuilder: (context, index) {
                          final category =
                              _productsByCategory.keys.elementAt(index);
                          final products = _productsByCategory[category]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category header
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${products.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

            // Products grid for this category
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.70,
                                ),
                                itemCount: products.length,
                                itemBuilder: (context, productIndex) {
                                  final product = products[productIndex];
                                  return _buildProductCard(product);
                                },
                              ),

                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                    ),
                    // Request Products button at the end
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildRequestProductsButton(),
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
        CartService().addToCart(product, 1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.productName} added to cart'),
            backgroundColor: const Color(0xFF4F46E5),
          ),
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

  Widget _buildRequestProductsButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _requestProducts,
        icon: const Icon(Icons.request_quote_outlined, size: 20),
        label: Text(
          'Request Products from ${widget.brand.name}',
          style: const TextStyle(
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
