import 'package:flutter/material.dart';

/// A horizontal row of trust signals for product pages.
///
/// Displays icons and labels like "Genuine Product", "Fast Delivery", etc.
class TrustSignalRow extends StatelessWidget {
  final List<TrustSignal>? signals;

  const TrustSignalRow({super.key, this.signals});

  static const List<TrustSignal> defaultSignals = [
    TrustSignal(
      icon: Icons.verified,
      label: 'Genuine',
      color: Color(0xFF10B981),
    ),
    TrustSignal(
      icon: Icons.local_shipping,
      label: 'Fast Delivery',
      color: Color(0xFF3B82F6),
    ),
    TrustSignal(
      icon: Icons.replay,
      label: 'Easy Returns',
      color: Color(0xFFF59E0B),
    ),
    TrustSignal(
      icon: Icons.security,
      label: 'Secure Pay',
      color: Color(0xFF8B5CF6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = signals ?? defaultSignals;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((signal) => _buildSignal(signal)).toList(),
      ),
    );
  }

  Widget _buildSignal(TrustSignal signal) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: signal.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            signal.icon,
            size: 16,
            color: signal.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          signal.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class TrustSignal {
  final IconData icon;
  final String label;
  final Color color;

  const TrustSignal({
    required this.icon,
    required this.label,
    required this.color,
  });
}
