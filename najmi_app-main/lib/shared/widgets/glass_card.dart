import 'dart:ui';
import 'package:flutter/material.dart';

/// A premium glassmorphism card container.
///
/// Provides multiple variants:
/// - `GlassCard()` — Default surface (white 85% opacity)
/// - `GlassCard.elevated()` — Stronger shadow for elevated cards
/// - `GlassCard.frosted()` — Uses BackdropFilter blur for true glass
/// - `GlassCard.interactive()` — Adds press scale animation
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double opacity;
  final double blurSigma;
  final bool useFrostedBlur;
  final bool isInteractive;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  /// Default glass surface card
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.opacity = 0.85,
    this.blurSigma = 0,
    this.useFrostedBlur = false,
    this.isInteractive = false,
    this.onTap,
    this.backgroundColor,
    this.boxShadow,
    this.border,
  });

  /// Elevated variant with stronger shadow
  const GlassCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.opacity = 0.90,
    this.blurSigma = 0,
    this.useFrostedBlur = false,
    this.isInteractive = false,
    this.onTap,
    this.backgroundColor,
    this.border,
  }) : boxShadow = const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ];

  /// Frosted blur variant — true glassmorphism with BackdropFilter
  const GlassCard.frosted({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.opacity = 0.70,
    this.blurSigma = 12,
    this.isInteractive = false,
    this.onTap,
    this.backgroundColor,
    this.boxShadow,
    this.border,
  }) : useFrostedBlur = true;

  /// Interactive variant — adds subtle press animation
  const GlassCard.interactive({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.opacity = 0.85,
    this.blurSigma = 0,
    this.useFrostedBlur = false,
    this.onTap,
    this.backgroundColor,
    this.boxShadow,
    this.border,
  }) : isInteractive = true;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 0.02,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isInteractive) {
      _scaleController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isInteractive) {
      _scaleController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.isInteractive) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.backgroundColor ?? Colors.white.withValues(alpha: widget.opacity);
    final shadow = widget.boxShadow ??
        [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

    Widget cardContent = Container(
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.useFrostedBlur ? bgColor : bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
        boxShadow: shadow,
      ),
      child: widget.child,
    );

    // Wrap with BackdropFilter for frosted variant
    if (widget.useFrostedBlur && widget.blurSigma > 0) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: cardContent,
        ),
      );
    }

    // Wrap with scale animation for interactive variant
    if (widget.isInteractive || widget.onTap != null) {
      cardContent = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: widget.isInteractive
            ? AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  );
                },
                child: cardContent,
              )
            : cardContent,
      );
    }

    return cardContent;
  }
}
