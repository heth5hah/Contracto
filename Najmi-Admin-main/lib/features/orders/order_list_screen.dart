import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'orders_provider.dart';
import 'order_model.dart';
import 'order_details_dialog.dart';
import '../../core/services/admin_notification_service.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    // Listen to real-time return updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeListener();
    });
  }

  void _setupRealtimeListener() {
    final returnsStream = ref.read(newReturnsStreamProvider);
    
    returnsStream.whenData((returnData) {
      if (mounted) {
        // Show toast notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New return request for Order #${returnData['order_id']?.toString().substring(0, 8) ?? 'N/A'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Refresh orders after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          ref.invalidate(ordersProvider);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(filteredOrdersProvider);
    final statusFilter = ref.watch(ordersStatusFilterProvider);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton(context, ref, 'All Orders', null, statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'Pending', 'pending', statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'Confirmed', 'confirmed', statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'Processing', 'processing', statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'In Transport', 'in_transport', statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'Delivered', 'delivered', statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'Completed', 'completed', statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'Returned', 'returned', statusFilter),
                  const SizedBox(width: 12),
                  _buildTabButton(context, ref, 'Cancelled', 'cancelled', statusFilter),
                ],
              ),
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Order ID, Customer Name, or Email...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
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
                child: ordersAsync.when(
                  skipLoadingOnReload: true,
                  data: (orders) {
                    // Apply search filter
                    final filteredOrders = _searchQuery.isEmpty
                        ? orders
                        : orders.where((order) {
                            final orderId = (order.orderId ?? order.id).toLowerCase();
                            final customerName = (order.customerName ?? '').toLowerCase();
                            final email = (order.customerEmail ?? '').toLowerCase();
                            return orderId.contains(_searchQuery) ||
                                   customerName.contains(_searchQuery) ||
                                   email.contains(_searchQuery);
                          }).toList();
                    
                    if (filteredOrders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No orders found' : 'No orders match your search',
                              style: TextStyle(color: Colors.grey[500], fontSize: 18),
                            ),
                            if (_searchQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Try a different search term',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width - 48,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(Colors.transparent),
                                  dataRowColor: MaterialStateProperty.all(Colors.transparent),
                                  columnSpacing: 24,
                                  horizontalMargin: 0,
                                  dividerThickness: 1,
                                  columns: const [
                                    DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                    DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                    DataColumn(label: Text('Return Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                    DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                  ],
                              rows: filteredOrders.map((order) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(order.orderId ?? '#${order.id.substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                                    DataCell(Text(order.customerName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF334155)))),
                                    DataCell(_StatusBadge(status: order.status)),
                                    DataCell(_ReturnStatusBadge(returnStatus: order.returnStatus, returnCount: order.returnRequestCount)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('₹${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Color(0xFF334155))),
                                          if (order.paymentStatus?.toLowerCase() == 'paid' || order.paymentStatus?.toLowerCase() == 'captured' || order.paymentStatus?.toLowerCase() == 'success') ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF22C55E),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('PAID', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(dateFormat.format(order.createdAt), style: const TextStyle(color: Color(0xFF334155)))),
                                    DataCell(
                                      TextButton.icon(
                                        onPressed: () async {
                                          final result = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => OrderDetailsDialog(order: order),
                                          );
                                          
                                          // If dialog returned true, status was changed - refresh orders
                                          if (result == true) {
                                            ref.invalidate(ordersProvider);
                                          }
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
                          ),
                        ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, WidgetRef ref, String label, String? value, String? currentValue) {
    final isSelected = value == currentValue;
    return InkWell(
      onTap: () {
        ref.read(ordersStatusFilterProvider.notifier).state = value;
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [
             BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ReturnStatusBadge extends StatelessWidget {
  final String? returnStatus;
  final int? returnCount;
  
  const _ReturnStatusBadge({this.returnStatus, this.returnCount});

  @override
  Widget build(BuildContext context) {
    if (returnStatus == null || returnStatus == 'No Return') {
      return const Text(
        'No Return',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
        ),
      );
    }

    Color color;
    String label;
    IconData icon;

    switch (returnStatus) {
      case 'Return Requested':
        color = const Color(0xFFF59E0B); // Amber/Yellow
        label = '🟡 Return Requested';
        icon = Icons.pending_actions;
        break;
      case 'Partial Return':
        color = const Color(0xFF8B5CF6); // Purple
        label = 'Partial Return';
        icon = Icons.swap_horiz;
        break;
      case 'Return Approved':
        color = const Color(0xFF3B82F6); // Blue
        label = 'Return Approved';
        icon = Icons.check_circle_outline;
        break;
      case 'Return Completed':
        color = const Color(0xFF22C55E); // Green
        label = 'Return Completed';
        icon = Icons.check_circle;
        break;
      default:
        color = const Color(0xFF64748B);
        label = returnStatus ?? 'Unknown';
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (returnCount != null && returnCount! > 1)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$returnCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'completed':
        color = const Color(0xFF22C55E);
        label = 'Completed';
        break;
      case 'delivered':
        color = const Color(0xFF22C55E); // Green like completed
        label = 'Delivered';
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        label = 'Pending';
        break;
      case 'confirmed':
        color = const Color(0xFF3B82F6); // Blue
        label = 'Confirmed';
        break;
      case 'in_transport':
        color = const Color(0xFF8B5CF6); // Purple
        label = 'In Transport';
        break;
      case 'returned':
        color = const Color(0xFFEF4444); // Red
        label = 'Returned';
        break;
      case 'cancelled':
        color = const Color(0xFF64748B); // Slate/Grey for cancelled
        label = 'Cancelled';
        break;
      case 'processing':
        color = const Color(0xFF0EA5E9); // Light Blue
        label = 'Processing';
        break;
      default:
        color = const Color(0xFF64748B);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
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
}
