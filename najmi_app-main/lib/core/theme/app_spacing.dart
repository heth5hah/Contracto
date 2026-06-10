import 'package:flutter/material.dart';

/// Consistent spacing system for the app
class AppSpacing {
  // Base spacing unit (4px)
  static const double _baseUnit = 4.0;

  // Spacing scale
  static const double xs = _baseUnit; // 4px
  static const double sm = _baseUnit * 2; // 8px
  static const double md = _baseUnit * 4; // 16px
  static const double lg = _baseUnit * 6; // 24px
  static const double xl = _baseUnit * 8; // 32px
  static const double xxl = _baseUnit * 12; // 48px

  // Screen margins
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets horizontalPadding =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets verticalPadding = EdgeInsets.symmetric(vertical: md);

  // Component spacing
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  // List spacing
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: lg,
  );

  // Navigation spacing
  static const EdgeInsets navItemPadding = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 50.0;

  // Icon sizes
  static const double iconXs = 12.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // Component heights
  static const double buttonHeight = 48.0;
  static const double inputHeight = 48.0;
  static const double navBarHeight = 80.0;
  static const double appBarHeight = 56.0;
}
