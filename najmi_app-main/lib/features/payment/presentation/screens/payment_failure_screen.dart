import 'package:flutter/material.dart';

class PaymentFailureScreen extends StatelessWidget {
  final String? errorCode;
  final String? errorMessage;
  final double? amount;

  const PaymentFailureScreen({
    super.key,
    this.errorCode,
    this.errorMessage,
    this.amount,
  });

  static const _indigo = Color(0xFF4F46E5);
  static const _indigoLight = Color(0xFF6366F1);
  static const _dark = Color(0xFF1E293B);
  static const _slate500 = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _dark),
          ),
        ),
        title: const Text(
          'Payment Failed',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Error Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEF4444).withValues(alpha: 0.15),
                        const Color(0xFFFCA5A5).withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFEF4444),
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Payment Unsuccessful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 12),
              // Details Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (amount != null) ...[
                      _detailRow('Amount', '₹${amount!.toStringAsFixed(0)}'),
                      if (errorMessage != null || errorCode != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
                        ),
                    ],
                    if (errorMessage != null && errorMessage!.isNotEmpty)
                      _detailRow('Reason', errorMessage!),
                    if (errorCode != null && errorCode!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _detailRow('Error Code', errorCode!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Help text
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _indigo.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _indigo.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline_rounded, size: 16, color: _indigo),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No money was deducted from your account. You can safely retry the payment.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Retry Button
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_indigo, _indigoLight]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _indigo.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Retry Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Back Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Back to Checkout',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _slate500, fontWeight: FontWeight.w500)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
          ),
        ),
      ],
    );
  }
}
