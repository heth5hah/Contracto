import 'dart:convert';

import 'package:contracto_app/core/config/payment_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Result object returned from payment-related operations
class PaymentResult {
  final bool success;
  final String message;
  final String? orderId;

  PaymentResult({
    required this.success,
    required this.message,
    this.orderId,
  });
}

/// Service wrapper for Razorpay SDK and Orders API
class RazorpayService {
  Razorpay? _razorpay;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.razorpay.com/v1',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Initialize Razorpay instance and register callbacks
  void initialize({
    required Function(PaymentSuccessResponse) onPaymentSuccess,
    required Function(PaymentFailureResponse) onPaymentFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay?.clear();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, onPaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, onPaymentFailure);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  /// Dispose and remove listeners
  void dispose() {
    try {
      _razorpay?.clear();
      _razorpay = null;
    } catch (_) {
      // Ignore dispose errors
    }
  }

  /// Create an order using Razorpay Orders API
  Future<Map<String, dynamic>> createPaymentOrder({
    required double amount,
    required String currency,
    required String receipt,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      // Amount must be in the smallest currency unit (paise)
      final int amountInPaise = (amount * 100).round();

      final String keyId = PaymentConfig.razorpayKey;
      final String keySecret = PaymentConfig.razorpaySecret;
      final String basicAuth =
          'Basic ${base64Encode(utf8.encode('$keyId:$keySecret'))}';

      final response = await _dio.post(
        '/orders',
        data: {
          'amount': amountInPaise,
          'currency': currency,
          'receipt': receipt,
          'payment_capture': 1,
          'notes': {
            'customer_name': customerName,
            'customer_email': customerEmail,
            'customer_phone': customerPhone,
          },
        },
        options: Options(
          headers: {
            'Authorization': basicAuth,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'order_id': response.data['id'],
        };
      }

      return {
        'success': false,
        'error': 'Failed with status ${response.statusCode}',
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Razorpay createPaymentOrder DioError: ${e.message}');
        print('Response data: ${e.response?.data}');
      }
      
      // Try to extract specific error message from Razorpay response
      String errorMessage = e.message ?? 'Unknown network error';
      if (e.response?.data != null && e.response!.data is Map) {
        final data = e.response!.data as Map;
        if (data.containsKey('error') && data['error'] is Map) {
          errorMessage = data['error']['description'] ?? errorMessage;
        } else if (data.containsKey('description')) {
           errorMessage = data['description'];
        }
      }
      
      return {
        'success': false,
        'error': 'Payment Init Failed: $errorMessage',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Razorpay createPaymentOrder error: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Launch Razorpay Checkout with the provided order
  void startPayment({
    required String orderId,
    required String keyId,
    required double amount,
    required String currency,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
    String? prefillMethod,
    String? description,
  }) {
    final int amountInPaise = (amount * 100).round();

    // Format phone number for Razorpay (remove +91, spaces, and ensure 10 digits)
    String formattedPhone = customerPhone;

    if (formattedPhone.startsWith('+91')) {
      formattedPhone = formattedPhone.substring(3);
    }
    formattedPhone = formattedPhone.replaceAll(RegExp(r'[^\d]'), '');

    // Ensure it's exactly 10 digits for Indian numbers
    if (formattedPhone.length > 10) {
      formattedPhone = formattedPhone.substring(formattedPhone.length - 10);
    }

    final Map<String, dynamic> options = {
      'key': keyId,
      'amount': amountInPaise,
      'currency': currency,
      'name': 'Contracto',
      'description': description ?? 'Order Payment',
      'order_id': orderId,
      'prefill': {
        'name': prefillName ?? customerName,
        'email': prefillEmail ?? customerEmail,
        'contact': prefillContact ?? formattedPhone,
        if (prefillMethod != null) 'method': prefillMethod,
      },
      'retry': {'enabled': true, 'max_count': 1},
      'theme': {'color': '#0C6CF2'},
    };

    _razorpay?.open(options);
  }
}
