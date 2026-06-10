class PaymentConfig {
  // Razorpay Configuration
  // Replace these with your actual Razorpay test keys
  static const String razorpayKeyId = 'rzp_live_RWSbkwhpMBCNXI';
  static const String razorpayKeySecret = 'xz16LwR10tv7ZMDL1iP3K49l';

  // For production, use these keys instead:
  // static const String razorpayKeyId = 'rzp_live_YOUR_LIVE_KEY_ID';
  // static const String razorpayKeySecret = 'YOUR_LIVE_SECRET';

  static const String defaultCurrency = 'INR';
  static const bool deliveryChargeEnabled = true;
  static const double baseDeliveryCharge = 100.0;
  static const double freeDeliveryThreshold = 1000.0;
  static const double gstPercentage = 0.18; // 18%

  // Test Mode
  static const bool isTestMode = true; // Set to false for production

  // Get the appropriate key based on environment
  static String get razorpayKey =>
      isTestMode ? razorpayKeyId : 'rzp_live_YOUR_LIVE_KEY_ID';

  // Get the appropriate secret based on environment
  static String get razorpaySecret =>
      isTestMode ? razorpayKeySecret : 'YOUR_LIVE_SECRET';

  // Payment Methods
  static const List<String> supportedPaymentMethods = [
    'card',
    'netbanking',
    'upi',
    'wallet',
    'emi',
  ];

  // UPI Apps
  static const List<String> supportedUpiApps = [
    'google_pay',
    'phonepe',
    'paytm',
    'amazon_pay',
    'bhim',
  ];

  // Card Networks
  static const List<String> supportedCardNetworks = [
    'visa',
    'mastercard',
    'rupay',
    'amex',
  ];
}
