import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:contracto_app/core/network/supabase_service.dart';

class PaymentService {
  static const String _razorpayKeyId =
      'rzp_test_YOUR_KEY_ID'; // Replace with your actual key
  static const String _razorpayKeySecret =
      'YOUR_KEY_SECRET'; // Replace with your actual secret

  late Razorpay _razorpay;

  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  Future<void> processCartPayment(
      BuildContext context, List<dynamic> cartItems) async {
    try {
      // Calculate total amount
      double totalAmount = cartItems.fold(
          0.0, (sum, item) => sum + (item.price * item.quantity));

      // Get user data
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create payment options
      var options = {
        'key': _razorpayKeyId,
        'amount':
            (totalAmount * 100).round(), // Razorpay expects amount in paise
        'currency': 'INR',
        'name': 'Contracto App',
        'description': 'Payment for ${cartItems.length} items',
        'prefill': {
          'contact': user.phone ?? '',
          'email': user.email ?? '',
          'name': user.userMetadata?['name'] ?? 'Customer',
        },
        'external': {
          'wallets': ['paytm', 'phonepe', 'gpay']
        }
      };

      // Open Razorpay payment
      _razorpay.open(options);
    } catch (e) {
      throw Exception('Failed to initialize payment: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Payment success will be handled by the calling widget
      // which has access to the cart service
      print('Payment successful: ${response.paymentId}');
    } catch (e) {
      print('Error handling payment success: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment failed: ${response.code} - ${response.message}');
    // Handle payment failure
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External wallet selected: ${response.walletName}');
  }

  Future<void> _createOrder(String paymentId, List<dynamic> cartItems) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Calculate total amount
      double totalAmount = cartItems.fold(
          0.0, (sum, item) => sum + (item.price * item.quantity));

      // Create order data
      final orderData = {
        'user_id': user.id,
        'payment_id': paymentId,
        'total_amount': totalAmount,
        'status': 'confirmed',
        'items': cartItems
            .map((item) => {
                  'product_id': item.product.id,
                  'product_name': item.product.productName,
                  'quantity': item.quantity,
                  'unit_price': item.price,
                  'total_price': item.price * item.quantity,
                  'quality_option_id': item.qualityOptionId,
                  'quality_option_name': item.qualityOptionName ?? 'Standard',
                })
            .toList(),
      };

      // Insert into orders table
      final response = await SupabaseService.client
          .from('orders')
          .insert(orderData)
          .select();

      // Handle response based on type
      if (response.isNotEmpty) {
        print('Order created successfully: ${response.first}');
      } else {
        throw Exception('Failed to create order: Unexpected response format');
      }
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  // Getter for Razorpay instance (for external access)
  Razorpay get razorpay => _razorpay;
}
