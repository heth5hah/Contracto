import 'dart:ui';
import 'package:flutter/material.dart';

/// A frosted-glass sticky bottom action bar.
///
/// Typically used for checkout CTAs, cart buttons, and other
/// sticky actions that should float above the content.
class StickyBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final Color? backgroundColor;
  final bool useSafeArea;

  const StickyBottomBar({
    super.key,
    required this.child,
    this.padding,
    this.blurSigma = 20,
    this.backgroundColor,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white.withValues(alpha: 0.90);

    Widget content = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (useSafeArea) {
      content = SafeArea(
        top: false,
        child: content,
      );
    }

    return content;
  }
}
