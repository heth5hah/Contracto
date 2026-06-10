import 'package:dio/dio.dart';

class EmailService {
  // ─────────────────────────────────────────────────────────────────────────
  // EmailJS — Free 200 emails/month. Uses YOUR Gmail directly.
  // NO domain DNS verification needed.
  // ─────────────────────────────────────────────────────────────────────────
  static const String _emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  static const String _serviceId  = 'service_ofdmkyg';
  static const String _templateId = 'template_t6ryw7l';
  static const String _publicKey  = 'fHVz0rwQyl1j64s0W';
  // Private key: EmailJS → Account → General → Private Key
  // Required because "Use Private Key" is enabled in EmailJS Security settings
  // You can also disable "Use Private Key" in EmailJS dashboard to avoid needing this
  static const String _privateKey = 'ieMICozate-JOa6AyseJ9';

  Future<bool> sendBankDetailsEmail({
    required String customerEmail,
    required String customerName,
    required String quotationId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String date,
  }) async {
    try {
      // Format items into plain text list
      String itemsList = '';
      for (var item in items) {
        final name  = item['product_name'] ?? 'Product';
        final qty   = item['quantity'] ?? 1;
        final price = item['total_price'] ?? item['unit_price'] ?? 0;
        itemsList += '• $qty x $name — ₹$price\n';
      }

      final shortId = quotationId.length >= 8
          ? quotationId.substring(0, 8).toUpperCase()
          : quotationId.toUpperCase();

      print('📧 [EmailJS] ══════════════════════════════════');
      print('📧 [EmailJS] Sending to : $customerEmail');
      print('📧 [EmailJS] Customer   : $customerName');
      print('📧 [EmailJS] Quotation  : $quotationId');
      print('📧 [EmailJS] Amount     : ₹$totalAmount');
      print('📧 [EmailJS] Service ID : $_serviceId');
      print('📧 [EmailJS] Template ID: $_templateId');
      print('📧 [EmailJS] ══════════════════════════════════');

      final response = await Dio().post(
        _emailJsUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            // No 'origin' header needed — non-browser API is enabled in EmailJS dashboard
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (status) => status != null && status < 600,
        ),
        data: {
          'service_id':   _serviceId,
          'template_id':  _templateId,
          'user_id':      _publicKey,
          'accessToken':  _privateKey,   // required when "Use Private Key" is ON
          'template_params': {
            'to_name':      customerName,
            'to_email':     customerEmail,
            'quotation_id': shortId,
            'date':         date,
            'total_amount': '₹$totalAmount',
            'items_list':   itemsList,
            // Bank details — used in template as plain variables
            'bank1_name':   'NAJMI ELECTRICALS AND HARDWRES PVT LTD',
            'bank1_ac':     '2512857806',
            'bank1_ifsc':   'KKBK0000627',
            'bank2_name':   'NAJMI STEEL AND HARDWRE',
            'bank2_ac':     '9612926258',
            'bank2_ifsc':   'KKBK0000627',
            'bank2_gst':    '27AAOFN9813E1ZY',
            // UPI QR code image — hosted on Supabase public storage
            'upi_qr_url':   'https://qboyfdwwrimditugblwo.supabase.co/storage/v1/object/public/brand-assets/WhatsApp%20Image%202026-05-18%20at%204.36.47%20PM.jpeg',
            'upi_id':       'paytmqr6vt276@ptys',
          },
        },
      );

      final statusCode = response.statusCode ?? 0;
      print('📧 [EmailJS] Response status: $statusCode');
      print('📧 [EmailJS] Response body: ${response.data}');

      if (statusCode >= 200 && statusCode < 300) {
        print('✅ [EmailJS] Email sent successfully to $customerEmail!');
        return true;
      } else {
        // Log the real error so we can debug
        print('❌ [EmailJS] FAILED — Status: $statusCode | Body: ${response.data}');
        // Return false so the UI can show the real error
        return false;
      }
    } on DioException catch (e) {
      print('❌ [EmailJS] Network error: ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      print('❌ [EmailJS] Unexpected error: $e');
      return false;
    }
  }
}
