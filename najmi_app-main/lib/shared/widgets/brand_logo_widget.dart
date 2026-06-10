import 'package:flutter/material.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
class BrandLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final BoxFit fit;
  final bool showPlaceholder;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const BrandLogoWidget({
    super.key,
    this.logoUrl,
    this.size = 60,
    this.fit = BoxFit.contain,
    this.showPlaceholder = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? CustomNetworkImage(
                imageUrl: logoUrl!,
                fit: fit,
                errorWidget: _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (!showPlaceholder) return const SizedBox.shrink();

    return Center(
      child: Icon(
        Icons.business,
        size: size * 0.5,
        color: Colors.grey[400],
      ),
    );
  }
}
