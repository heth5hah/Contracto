import 'package:flutter/material.dart';

class BulkDiscountBadge extends StatelessWidget {
  final int minQuantity;
  final double discountPercent;
  final bool isAnimated;

  const BulkDiscountBadge({
    super.key,
    required this.minQuantity,
    required this.discountPercent,
    this.isAnimated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_offer,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'Buy $minQuantity+ Save ${discountPercent.toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display all bulk discount rules for a product
class BulkDiscountList extends StatelessWidget {
  final List<BulkDiscountRule> rules;

  const BulkDiscountList({
    super.key,
    required this.rules,
  });

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.trending_down,
                size: 16,
                color: Color(0xFF059669),
              ),
              SizedBox(width: 6),
              Text(
                'Bulk Discounts Available',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rules.map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Buy ${rule.minQuantity}+ items: ${rule.discountPercent.toInt()}% OFF',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// Helper class for bulk discount rules (if not already in ProductModel)
class BulkDiscountRule {
  final int minQuantity;
  final double discountPercent;

  BulkDiscountRule({
    required this.minQuantity,
    required this.discountPercent,
  });
}
