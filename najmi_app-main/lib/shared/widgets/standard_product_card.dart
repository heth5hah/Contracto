import 'package:flutter/material.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';

class StandardProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onRequestQuote;
  final VoidCallback? onToggleWishlist;
  final bool isWishlisted;
  final bool showDiscount;
  final double? discountPercentage;
  final Color? imageBackgroundColor;

  const StandardProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.onRequestQuote,
    this.onToggleWishlist,
    this.isWishlisted = false,
    this.showDiscount = true,
    this.discountPercentage,
    this.imageBackgroundColor,
  });

  String _formatProductName(String name) {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.contains(RegExp(r'[0-9]'))) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = discountPercentage != null && discountPercentage! > 0;
    final formattedName = _formatProductName(product.productName);
    final needsQuoteRequest =
        product.category == 'Plumbing' || product.category == 'Painting';
    final bgColor = imageBackgroundColor ?? const Color(0xFFF1F5F9);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Area with Pastel Background ──
            AspectRatio(
              aspectRatio: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Stack(
                  children: [
                    // Pastel Background + Product Image (inset with rounded corners)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: product.photos.isNotEmpty
                            ? CustomNetworkImage(
                                imageUrl: product.photos.first,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Opacity(
                                    opacity: 0.3,
                                    child: Image.asset(
                                      'assets/images/contracto.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // Top-Left: Discount Badge
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${discountPercentage?.toInt()}% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                    // Top-Right: Wishlist Heart Icon
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onToggleWishlist,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            isWishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: isWishlisted
                                ? const Color(0xFFEF4444)
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Product Info (Flexible to prevent overflow) ──
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 6, 6),
                child: Row(
                  children: [
                    // Name + Price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formattedName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // Price Row
                          (!needsQuoteRequest &&
                                  product.finalPrice != null &&
                                  product.finalPrice! > 0)
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    if (product.mrp != null &&
                                        product.mrp! > product.finalPrice! &&
                                        hasDiscount)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text(
                                          '₹${product.mrp!.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.grey[400],
                                            decoration:
                                                TextDecoration.lineThrough,
                                            decorationColor: Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        '₹${product.finalPrice!.toStringAsFixed(0)}${product.unit != null && product.unit!.isNotEmpty ? ' /${product.unit}' : ''}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: hasDiscount 
                                              ? const Color(0xFF16A34A) // Green for discounted price
                                              : const Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Price on request',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange[700],
                                  ),
                                ),
                        ],
                      ),
                    ),

                    // Small arrow CTA
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Color(0xFF64748B),
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
}
