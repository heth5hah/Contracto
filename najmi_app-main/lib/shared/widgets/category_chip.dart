import 'package:flutter/material.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
class CategoryChip extends StatelessWidget {
  final String categoryName;
  final String? imageUrl;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? backgroundColor;
  final Color? textColor;

  const CategoryChip({
    super.key,
    required this.categoryName,
    this.imageUrl,
    this.icon,
    this.onTap,
    this.isSelected = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? (backgroundColor ?? const Color(0xFF2563EB))
        : Colors.grey[100];
    final fgColor = isSelected ? Colors.white : (textColor ?? Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (backgroundColor ?? const Color(0xFF2563EB))
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category icon or image
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomNetworkImage(
                  imageUrl: imageUrl!,
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  errorWidget: Icon(
                    icon ?? Icons.category,
                    size: 16,
                    color: fgColor,
                  ),
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 16,
                color: fgColor,
              ),
            
            if (imageUrl != null || icon != null) const SizedBox(width: 6),
            
            // Category name
            Text(
              categoryName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
