
import 'dart:convert';
import 'package:dio/dio.dart';

class AdminRazorpayService {
  // Using keys found in mobile app config
  static const String _keyId = 'rzp_live_RWSbkwhpMBCNXI';
  static const String _keySecret = 'xz16LwR10tv7ZMDL1iP3K49l';
  
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.razorpay.com/v1',
    headers: {
      'Authorization': 'Basic ${base64Encode(utf8.encode('$_keyId:$_keySecret'))}',
      'Content-Type': 'application/json',
    },
  ));

  /// Process a refund for a specific payment ID
  static Future<Map<String, dynamic>> processRefund({
    required String paymentId,
    required double amount,
    Map<String, dynamic>? notes,
  }) async {
    try {
      // Amount in paise
      final int amountInPaise = (amount * 100).round();
      
      final response = await _dio.post(
        '/payments/$paymentId/refund',
        data: {
          'amount': amountInPaise,
          'notes': notes ?? {'reason': 'Admin initiated refund'},
          'speed': 'optimum', // 'normal' or 'optimum'
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'refund_id': response.data['id'],
          'status': response.data['status'],
          'data': response.data,
        };
      } else {
         return {
          'success': false,
          'error': 'Status ${response.statusCode}: ${response.statusMessage}',
        };
      }
    } on DioException catch (e) {
      String errorMsg = e.message ?? 'Unknown error';
      if (e.response != null) {
        try {
          errorMsg = e.response?.data['error']['description'] ?? errorMsg;
        } catch (_) {}
      }
      return {
        'success': false,
        'error': errorMsg,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
