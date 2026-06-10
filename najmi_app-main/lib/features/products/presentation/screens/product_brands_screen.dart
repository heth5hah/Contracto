import 'package:flutter/material.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/brands/presentation/screens/brand_products_screen.dart';
import 'package:contracto_app/features/products/data/services/product_service.dart';

class ProductBrandsScreen extends StatefulWidget {
  final String productName;

  const ProductBrandsScreen({
    super.key,
    required this.productName,
  });

  @override
  State<ProductBrandsScreen> createState() => _ProductBrandsScreenState();
}

class _ProductBrandsScreenState extends State<ProductBrandsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _productBrands = [];
  final _productService = ProductService();

  @override
  void initState() {
    super.initState();
    _loadProductBrands();
  }

  Future<void> _loadProductBrands() async {
    try {
      final productBrands =
          await _productService.getProductBrands(widget.productName);
      setState(() {
        _productBrands = productBrands;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onBrandTap(Map<String, dynamic> productBrand) {
    final brandData = productBrand['brands'] as Map<String, dynamic>;
    final brand = BrandModel(
      id: brandData['id'] as String,
      name: brandData['name'] as String,
      logoUrl: brandData['logo_url'] as String?,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandProductsScreen(brand: brand),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Brands',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'for "${widget.productName}"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _productBrands.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No brands found for "${widget.productName}"',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _productBrands.length,
                  itemBuilder: (context, index) {
                    final productBrand = _productBrands[index];
                    final brandData =
                        productBrand['brands'] as Map<String, dynamic>;
                    final productName = productBrand['product_name'] as String;

                    return GestureDetector(
                      onTap: () => _onBrandTap(productBrand),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                          
                        ),
                        child: Row(
                          children: [
                            // Brand logo
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: brandData['logo_url'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CustomNetworkImage(
                                        imageUrl: brandData['logo_url'] as String,
                                        fit: BoxFit.cover,
                                        errorWidget: Icon(Icons.business,
                                            color: Colors.grey[400],
                                            size: 24),
                                      ),
                                    )
                                  : Icon(Icons.business,
                                      color: Colors.grey[400], size: 24),
                            ),
                            const SizedBox(width: 16),
                            // Brand and product info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    brandData['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    productName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'View Products',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Arrow icon
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
