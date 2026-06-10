import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../products/products_provider.dart';
import '../orders/orders_provider.dart';
import '../quotations/quotations_provider.dart';
import '../users/users_provider.dart';
import '../orders/order_model.dart';
import '../orders/order_details_dialog.dart';
import '../enquiries/enquiries_provider.dart';
import '../../main.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all necessary providers
    final productsAsync = ref.watch(productsProvider);
    final productsCountAsync = ref.watch(productsCountProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final quotationsAsync = ref.watch(quotationsProvider);
    final usersAsync = ref.watch(usersProvider);
    final enquiriesAsync = ref.watch(enquiriesProvider);
    final revenueAsync = ref.watch(totalRevenueProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 600;
                final isMedium = constraints.maxWidth < 1100;
                
                // Adjusting to 3 columns on large screens for 5-6 cards to look better
                final double itemWidth = isSmall 
                  ? constraints.maxWidth 
                  : isMedium 
                    ? (constraints.maxWidth - 24) / 2 
                    : (constraints.maxWidth - 24 * 2) / 3;

                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        title: 'Total Revenue',
                        value: revenueAsync.when(
                          data: (val) => 'Rs ${NumberFormat('#,##,###').format(val)}',
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        icon: Icons.payments_outlined,
                        color: const Color(0xFF10B981),
                        bgColor: const Color(0xFFECFDF5),
                        onTap: () => context.go('/orders'),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        title: 'Total Products',
                        value: productsCountAsync.when(
                          data: (count) => count.toString(),
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        icon: Icons.inventory_2_outlined,
                        color: const Color(0xFF3B82F6),
                        bgColor: const Color(0xFFEFF6FF),
                        onTap: () => context.go('/products'),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        title: 'Orders Today',
                        value: ordersAsync.when(
                          data: (d) {
                            final today = DateTime.now();
                            final count = d.where((o) {
                              return o.createdAt.year == today.year &&
                                  o.createdAt.month == today.month &&
                                  o.createdAt.day == today.day;
                            }).length;
                            return count.toString();
                          },
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        icon: Icons.shopping_cart_outlined,
                        color: const Color(0xFF22C55E),
                        bgColor: const Color(0xFFF0FDF4),
                        onTap: () => context.go('/orders'),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        title: 'New Quotations',
                        value: quotationsAsync.when(
                          data: (d) => d.length.toString(),
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        icon: Icons.description_outlined,
                        color: const Color(0xFFF97316),
                        bgColor: const Color(0xFFFFF7ED),
                        onTap: () => context.go('/quotations'),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        title: 'Active Users',
                        value: usersAsync.when(
                          data: (d) => d.length.toString(),
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        icon: Icons.people_outline,
                        color: const Color(0xFFA855F7),
                        bgColor: const Color(0xFFFAF5FF),
                        onTap: () => context.go('/users'),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Requested Products (Product Enquiries from mobile app search "Request product")
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Requested Products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      enquiriesAsync.when(
                        data: (items) {
                          if (items.isEmpty) return const SizedBox.shrink();
                          // Count pending product enquiries
                          final pendingCount =
                              items.where((e) => e.status.toLowerCase() == 'pending').length;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$pendingCount pending',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  enquiriesAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No product requests yet',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        );
                      }

                      // Show the 5 most recent product enquiries
                      final recent = items.take(5).toList();

                      return Column(
                        children: [
                          for (final enquiry in recent)
                            GestureDetector(
                              onTap: () => _showEnquiryDetailsDialog(context, ref, enquiry),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.search,
                                        size: 18,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            enquiry.productName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          if (enquiry.category != null &&
                                              enquiry.category!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              enquiry.category!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            enquiry.message,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                DateFormat('yyyy-MM-dd HH:mm')
                                                    .format(enquiry.createdAt),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF9CA3AF),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (enquiry.contactEmail != null ||
                                                  enquiry.contactPhone != null)
                                                Text(
                                                  enquiry.contactEmail ??
                                                      enquiry.contactPhone ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF4B5563),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: enquiry.status.toLowerCase() == 'pending'
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        enquiry.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: enquiry.status.toLowerCase() == 'pending'
                                              ? const Color(0xFF92400E)
                                              : const Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Error: $err'),
                  ),
                ],
              ),
            ),

            // Recent Orders Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/orders'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('View All Orders'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ordersAsync.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Text('No orders found'),
                          ),
                        );
                      }
                      // Take top 5
                      final recentOrders = orders.take(5).toList();
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.transparent),
                                dataRowColor: MaterialStateProperty.all(Colors.transparent),
                                columnSpacing: 20,
                                horizontalMargin: 0,
                                columns: const [
                                  DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                  DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                  DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                ],
                                rows: recentOrders.map((order) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(order.orderId ?? order.id.substring(0, 8), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                                      DataCell(Text(order.customerName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF334155)))),
                                      DataCell(_buildStatusBadge(order.status)),
                                      DataCell(Text('Rs ${order.totalAmount?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: Color(0xFF334155)))),
                                      DataCell(Text(DateFormat('yyyy-MM-dd').format(order.createdAt), style: const TextStyle(color: Color(0xFF334155)))),
                                      DataCell(
                                        TextButton.icon(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => OrderDetailsDialog(order: order),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility_outlined, size: 18),
                                          label: const Text('View'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF334155),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Error: $err'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return _HoverStatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      bgColor: bgColor,
      onTap: onTap,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bgColor;
    String label;

    switch (status.toLowerCase()) {
      case 'completed':
        color = const Color(0xFF22C55E);
        bgColor = const Color(0xFFDCFCE7); // green-100
        label = 'Completed';
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFEF3C7); // amber-100
        label = 'Pending';
        break;
      case 'confirmed':
        color = const Color(0xFF3B82F6); // Blue for confirmed
        bgColor = const Color(0xFFDBEAFE); 
        label = 'Confirmed';
        break;
      case 'in_transport':
        color = const Color(0xFF8B5CF6); // Purple
        bgColor = const Color(0xFFF3E8FF);
        label = 'In Transport';
        break;
      case 'delivered':
        color = const Color(0xFF22C55E); 
        bgColor = const Color(0xFFDCFCE7);
        label = 'Delivered';
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFEE2E2); // red-100
        label = 'Cancelled';
        break;
      case 'processing':
        color = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFDBEAFE); // blue-100
        label = 'Processing';
        break;
      case 'returned':
        color = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFEE2E2);
        label = 'Returned';
        break;
      default:
        color = const Color(0xFF64748B);
        bgColor = const Color(0xFFF1F5F9); // slate-100
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color, // Using solid color for badge background based on screenshot style
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEnquiryDetailsDialog(
    BuildContext context,
    WidgetRef ref,
    AdminEnquiry enquiry,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(enquiry.productName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (enquiry.category != null && enquiry.category!.isNotEmpty) ...[
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enquiry.category!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Requirements',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enquiry.message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enquiry.contactEmail ?? enquiry.contactPhone ?? 'Not provided',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Created At',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(enquiry.createdAt),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusBadge(enquiry.status),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            if (enquiry.status.toLowerCase() == 'pending')
              ElevatedButton(
                onPressed: () async {
                  try {
                    final supabase = ref.read(supabaseProvider);
                    await supabase
                        .from('enquiries')
                        .update({'status': 'resolved'})
                        .eq('id', enquiry.id);
                    ref.invalidate(enquiriesProvider);
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request approved successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to approve request: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Approve Request'),
              ),
          ],
        );
      },
    );
  }
}

class _HoverStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _HoverStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  State<_HoverStatCard> createState() => _HoverStatCardState();
}

class _HoverStatCardState extends State<_HoverStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.02),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
