import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:contracto_app/core/config/app_config.dart';

class AppTheme {
  static const _lightFontFamily = 'Inter';
  static const _darkFontFamily = 'Inter';

  // Color Palette
  static const Color _primaryColor = Color(0xFF4F46E5); // Indigo 600 - Premium and modern
  static const Color _secondaryColor = Color(0xFF1E293B); // Slate 800
  static const Color _accentColor = Color(0xFFF59E0B); // Amber 500
  static const Color _successColor = Color(0xFF10B981); // Emerald 500
  static const Color _errorColor = Color(0xFFEF4444); // Red 500
  static const Color _warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color _surfaceColor = Color(0xFFF8FAFC); // Slate 50
  static const Color _backgroundColor = Color(0xFFFFFFFF); // White

  // Glassmorphism Tokens
  static const Color glassTint = Color(0xD9FFFFFF); // White @ ~85%
  static const Color glassBorder = Color(0x4DFFFFFF); // White @ ~30%
  static const Color glassOverlay = Color(0xB3FFFFFF); // White @ ~70%

  // Dark Theme Colors
  static const Color _darkPrimaryColor = Color(0xFF3B82F6); // Blue 500
  static const Color _darkSecondaryColor = Color(0xFF1E293B); // Slate 800
  static const Color _darkBackgroundColor = Color(0xFF0F172A); // Slate 900
  static const Color _darkSurfaceColor = Color(0xFF1E293B); // Slate 800

  // Neutral Colors - Improved contrast ratios
  static const Color _neutral50 = Color(0xFFF8FAFC);
  static const Color _neutral100 = Color(0xFFF1F5F9);
  static const Color _neutral200 = Color(0xFFE2E8F0);
  static const Color _neutral300 = Color(0xFFCBD5E1);
  static const Color _neutral400 = Color(0xFF8B9AAF); // Improved from #94A3B8
  static const Color _neutral600 = Color(0xFF475569);
  static const Color _neutral700 = Color(0xFF334155);
  static const Color _neutral800 = Color(0xFF1E293B);
  static const Color _neutral900 = Color(0xFF0F172A);

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _lightFontFamily,
    colorScheme: const ColorScheme.light(
      primary: _primaryColor,
      secondary: _secondaryColor,
      tertiary: _accentColor,
      surface: _surfaceColor,
      error: _errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: _neutral700,
      onError: Colors.white,
      surfaceContainerHighest: _neutral100,
      outline: _neutral300,
      shadow: _neutral900,
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: _backgroundColor,
      foregroundColor: _neutral700,
      elevation: 0,
      scrolledUnderElevation: 1,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _neutral700,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: _backgroundColor,
      elevation: 2,
      shadowColor: _neutral900.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
      ),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: _lightFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        side: const BorderSide(color: _neutral300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: _lightFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: _lightFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _neutral50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        borderSide: const BorderSide(color: _neutral300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        borderSide: const BorderSide(color: _neutral300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        borderSide: const BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
        borderSide: const BorderSide(color: _errorColor, width: 2),
      ),
      labelStyle: const TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: _neutral600,
      ),
      hintStyle: const TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 16,
        color: _neutral400,
      ),
      contentPadding: const EdgeInsets.all(20),
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _backgroundColor,
      selectedItemColor: _primaryColor,
      unselectedItemColor: _neutral400,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: _neutral900,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _neutral900,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _neutral900,
        letterSpacing: -0.25,
      ),
      headlineLarge: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _neutral900,
        letterSpacing: -0.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _neutral900,
        letterSpacing: -0.25,
      ),
      headlineSmall: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _neutral900,
      ),
      titleLarge: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _neutral900,
      ),
      titleMedium: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _neutral900,
      ),
      titleSmall: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _neutral900,
      ),
      bodyLarge: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: _neutral700,
      ),
      bodyMedium: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _neutral700,
      ),
      bodySmall: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _neutral600,
      ),
      labelLarge: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _neutral700,
      ),
      labelMedium: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _neutral700,
      ),
      labelSmall: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: _neutral600,
      ),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: _neutral700,
      size: 24,
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      backgroundColor: _neutral100,
      disabledColor: _neutral100,
      selectedColor: _primaryColor,
      secondarySelectedColor: _primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      labelStyle: const TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _neutral700,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),

    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: _neutral200,
      thickness: 1,
      space: 1,
    ),

    // Switch Theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primaryColor;
        }
        return _neutral400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primaryColor.withValues(alpha: 0.3);
        }
        return _neutral200;
      }),
    ),

    // Slider Theme
    sliderTheme: const SliderThemeData(
      activeTrackColor: _primaryColor,
      inactiveTrackColor: _neutral200,
      thumbColor: _primaryColor,
      overlayColor: Color(0x1F1E293B),
      valueIndicatorColor: _primaryColor,
    ),

    // Progress Indicator Theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _primaryColor,
      linearTrackColor: _neutral200,
      circularTrackColor: _neutral200,
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
    ),

    // Snackbar Theme
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: _neutral800,
      contentTextStyle: TextStyle(
        fontFamily: _lightFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _darkFontFamily,
    colorScheme: const ColorScheme.dark(
      primary: _darkPrimaryColor,
      secondary: _darkSecondaryColor,
      tertiary: _accentColor,
      surface: _darkSurfaceColor,
      error: _errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.black,
      onSurface: _neutral100,
      onError: Colors.white,
      surfaceContainerHighest: _neutral700,
      outline: _neutral600,
      shadow: Colors.black,
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkBackgroundColor,
      foregroundColor: _neutral100,
      elevation: 0,
      scrolledUnderElevation: 1,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _neutral100,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: _darkSurfaceColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.defaultBorderRadius),
      ),
    ),

    // Text Theme for Dark Mode
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: _neutral100,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _neutral100,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _neutral100,
        letterSpacing: -0.25,
      ),
      headlineLarge: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _neutral100,
        letterSpacing: -0.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _neutral100,
        letterSpacing: -0.25,
      ),
      headlineSmall: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _neutral100,
      ),
      titleLarge: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _neutral100,
      ),
      titleMedium: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _neutral100,
      ),
      titleSmall: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _neutral100,
      ),
      bodyLarge: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: _neutral300,
      ),
      bodyMedium: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _neutral300,
      ),
      bodySmall: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _neutral400,
      ),
      labelLarge: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _neutral300,
      ),
      labelMedium: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _neutral300,
      ),
      labelSmall: TextStyle(
        fontFamily: _darkFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: _neutral400,
      ),
    ),
  );

  // Animation Configurations
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Animation Curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve elasticCurve = Curves.elasticOut;

  // Custom Colors
  static const Color scaffoldBackgroundLight = _backgroundColor;
  static const Color scaffoldBackgroundDark = _darkBackgroundColor;

  // Status Colors
  static const Color success = _successColor;
  static const Color error = _errorColor;
  static const Color warning = _warningColor;
  static const Color info = _secondaryColor;

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Glass-specific gradient for surfaces
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xE6FFFFFF), Color(0xD9FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Deep brand gradient for splash and hero areas
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [_accentColor, _warningColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow Configurations
  static List<BoxShadow> get lightShadow => [
        BoxShadow(
          color: _neutral900.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: _neutral900.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get heavyShadow => [
        BoxShadow(
          color: _neutral900.withValues(alpha: 0.08),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];
}
