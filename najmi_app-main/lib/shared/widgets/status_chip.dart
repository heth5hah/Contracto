import 'package:flutter/material.dart';

/// A color-coded status indicator chip.
///
/// Automatically maps common status strings to colors,
/// or accepts custom color/label overrides.
class StatusChip extends StatelessWidget {
  final String status;
  final Color? color;
  final String? label;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const StatusChip({
    super.key,
    required this.status,
    this.color,
    this.label,
    this.fontSize = 11,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _getStatusColor(status);
    final chipLabel = label ?? _getStatusLabel(status);

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: chipColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        chipLabel,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: chipColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'approved':
      case 'active':
      case 'delivered':
      case 'completed':
        return const Color(0xFF10B981); // Emerald
      case 'processing':
      case 'pending':
      case 'in_review':
        return const Color(0xFFF59E0B); // Amber
      case 'shipped':
      case 'in_transport':
      case 'in_transit':
        return const Color(0xFF3B82F6); // Blue
      case 'cancelled':
      case 'rejected':
      case 'failed':
      case 'blocked':
        return const Color(0xFFEF4444); // Red
      case 'refunded':
      case 'returned':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  static String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'in_transport':
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'refunded':
        return 'Refunded';
      case 'completed':
        return 'Completed';
      case 'active':
        return 'Active';
      case 'blocked':
        return 'Blocked';
      case 'failed':
        return 'Failed';
      default:
        if (status.isNotEmpty) {
          return status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
        }
        return status;
    }
  }
}
