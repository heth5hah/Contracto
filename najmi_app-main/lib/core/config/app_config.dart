class AppConfig {
  // App Information
  static const String appName = 'Contracto';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Professional B2B Contracting Platform - Electrical Equipment & Hardware Solutions';
  static const String companyName = 'Contracto & Hardwares Private Limited';

  // Theme Configuration
  static const String primaryColorHex = '#1E293B'; // Slate 800
  static const String secondaryColorHex = '#3B82F6'; // Blue 500
  static const String accentColorHex = '#F59E0B'; // Amber 500
  static const String successColorHex = '#10B981'; // Emerald 500
  static const String errorColorHex = '#EF4444'; // Red 500
  static const String warningColorHex = '#F59E0B'; // Amber 500
  static const String surfaceColorHex = '#F8FAFC'; // Slate 50
  static const String backgroundColorHex = '#FFFFFF'; // White

  // API Configuration
  static const String baseApiUrl = 'https://api.contractobuild.com';
  static const int apiTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;

  // Supabase Configuration
  static const String supabaseUrl = 'https://qboyfdwwrimditugblwo.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw';

  // Storage Configuration
  static const String storageUrl =
      'https://qboyfdwwrimditugblwo.supabase.co/storage/v1/s3';
  static const String bucketName = 'contracto-files';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Configuration
  static const int cacheExpirationHours = 24;
  static const int maxCacheSize = 100; // MB

  // Animation Configuration
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // UI Configuration
  static const double defaultBorderRadius = 16.0;
  static const double defaultPadding = 16.0;
  static const double defaultSpacing = 8.0;
  static const double defaultElevation = 2.0;

  // Contact Information
  static const String contactPhone = '+91 8291252525';
  static const String contactPhoneDisplay = '+91 82912 52525'; // Formatted for display
  static const String contactWhatsApp = '918291252525'; // WhatsApp (without + or spaces)
  static const String contactEmail = 'support@contractobuild.com';
  static const String customerServiceEmail = 'support@contractobuild.com';
  static const String websiteUrl = 'https://contractobuild.com';

  // Social Media
  static const String linkedInUrl = 'https://linkedin.com/company/contracto';
  static const String twitterUrl = 'https://twitter.com/contracto';

  // Legal
  static const String privacyPolicyUrl = 'https://www.contracto.com/privacy';
  static const String termsOfServiceUrl = 'https://www.contracto.com/terms';

  // Feature Flags
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enableBiometric = true;
  static const bool enableDarkMode = true;

  // Business Configuration
  static const List<String> supportedCurrencies = ['INR', 'USD', 'EUR', 'GBP'];
  static const String defaultCurrency = 'INR';
  static const List<String> supportedLanguages = ['en', 'es', 'fr'];
  static const String defaultLanguage = 'en';

  // File Upload Configuration
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];
  static const List<String> supportedDocumentFormats = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx'
  ];
}
