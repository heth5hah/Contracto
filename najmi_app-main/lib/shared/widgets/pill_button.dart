import 'package:flutter/material.dart';

/// A premium pill-shaped button with optional gradient.
///
/// Variants:
/// - `PillButton()` — Solid color pill
/// - `PillButton.gradient()` — Gradient fill
/// - `PillButton.outlined()` — Outlined pill with transparent fill
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Gradient? gradient;
  final bool outlined;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry? padding;
  final double? width;

  /// Solid pill button
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.gradient,
    this.outlined = false,
    this.height = 52,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.padding,
    this.width,
  });

  /// Gradient pill button
  const PillButton.gradient({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.foregroundColor = Colors.white,
    this.height = 52,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.padding,
    this.width,
  })  : backgroundColor = null,
        gradient = const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        outlined = false;

  /// Outlined pill button
  const PillButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.foregroundColor,
    this.height = 52,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.padding,
    this.width,
  })  : backgroundColor = Colors.transparent,
        gradient = null,
        outlined = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary;
    final fg = foregroundColor ??
        (outlined ? theme.colorScheme.primary : Colors.white);

    if (gradient != null) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onPressed != null ? gradient : null,
            color: onPressed == null ? Colors.grey[300] : null,
            borderRadius: BorderRadius.circular(100),
            boxShadow: onPressed != null
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: isLoading ? null : onPressed,
              child: Center(child: _buildContent(fg)),
            ),
          ),
        ),
      );
    }

    if (outlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: fg.withValues(alpha: 0.3)),
            shape: const StadiumBorder(),
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          ),
          child: _buildContent(fg),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        ),
        child: _buildContent(fg),
      ),
    );
  }

  Widget _buildContent(Color fg) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}
