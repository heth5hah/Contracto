import 'package:flutter/material.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/shared/widgets/standard_product_card.dart';

class ProductGrid1x3 extends StatelessWidget {
  final List<ProductModel> products;
  final Function(ProductModel)? onProductTap;
  final Function(ProductModel)? onAddToCart;
  final Function(ProductModel)? onRequestQuote;
  final String? title;
  final VoidCallback? onViewAll;

  const ProductGrid1x3({
    super.key,
    required this.products,
    this.onProductTap,
    this.onAddToCart,
    this.onRequestQuote,
    this.title,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    // Take only first 3 products for 1x3 grid
    final displayProducts = products.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and View All button
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // 1x3 Grid
        SizedBox(
          height: 280, // Fixed height for consistent layout
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayProducts.length,
            itemBuilder: (context, index) {
              final product = displayProducts[index];
              return Container(
                width: MediaQuery.of(context).size.width * 0.42, // ~40% of screen width
                margin: EdgeInsets.only(
                  right: index < displayProducts.length - 1 ? 12 : 0,
                ),
                child: StandardProductCard(
                  product: product,
                  onTap: onProductTap != null
                      ? () => onProductTap!(product)
                      : null,
                  onAddToCart: onAddToCart != null
                      ? () => onAddToCart!(product)
                      : null,
                  onRequestQuote: onRequestQuote != null
                      ? () => onRequestQuote!(product)
                      : null,
                  showDiscount: product.discountPercent != null,
                  discountPercentage: product.discountPercent,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Alternative grid layout for responsive design
class ProductGrid1x3Responsive extends StatelessWidget {
  final List<ProductModel> products;
  final Function(ProductModel)? onProductTap;
  final Function(ProductModel)? onAddToCart;
  final Function(ProductModel)? onRequestQuote;
  final String? title;
  final VoidCallback? onViewAll;

  const ProductGrid1x3Responsive({
    super.key,
    required this.products,
    this.onProductTap,
    this.onAddToCart,
    this.onRequestQuote,
    this.title,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final displayProducts = products.take(3).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate card width based on screen size
    final cardWidth = (screenWidth - 48) / 3; // 3 cards with 16px padding on sides and 8px gaps

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and View All button
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // 1x3 Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: displayProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < displayProducts.length - 1 ? 8 : 0,
                  ),
                  child: StandardProductCard(
                    product: product,
                    onTap: onProductTap != null
                        ? () => onProductTap!(product)
                        : null,
                    onAddToCart: onAddToCart != null
                        ? () => onAddToCart!(product)
                        : null,
                    onRequestQuote: onRequestQuote != null
                        ? () => onRequestQuote!(product)
                        : null,
                    showDiscount: product.discountPercent != null,
                    discountPercentage: product.discountPercent,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
