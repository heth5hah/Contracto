import 'dart:async';
import 'package:flutter/material.dart';
import 'package:contracto_app/features/orders/data/models/order_model.dart';
import 'package:contracto_app/features/orders/data/services/order_service.dart';
import 'package:contracto_app/features/orders/presentation/screens/order_tracking_screen.dart';
import 'package:contracto_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:contracto_app/core/services/user_realtime_service.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/auth/presentation/screens/login_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  static String? pendingOrderId;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _orderService = OrderService();
  final UserRealtimeService _realtimeService = UserRealtimeService();
  StreamSubscription? _orderStatusSubscription;

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _error;
  bool _isGuest = false;

  // Theme constants
  static const _indigo = Color(0xFF4F46E5);
  static const _indigoLight = Color(0xFF6366F1);
  static const _dark = Color(0xFF1E293B);
  static const _slate500 = Color(0xFF64748B);
  static const _bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _isGuest = SupabaseService.instance.currentUser == null;
    if (!_isGuest) {
      _loadOrders();
      _setupRealtimeListener();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _orderStatusSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    _realtimeService.initialize();
    _orderStatusSubscription =
        _realtimeService.orderStatusUpdatedStream.listen((updateData) {
      print('🔄 Order status updated: ${updateData['new_status']}');
      final orderId = updateData['order_id'] as String?;
      if (orderId != null && mounted) {
        final orderIndex = _orders.indexWhere((o) => o.id == orderId);
        if (orderIndex != -1) {
          setState(() {
            if (updateData['order_data'] != null) {
              // Try to preserve items since they might not be in the order_data payload
              final preservedItems = _orders[orderIndex].items;
              final Map<String, dynamic> mergedData = Map<String, dynamic>.from(updateData['order_data'] as Map);
              if (mergedData['items'] == null || (mergedData['items'] as List).isEmpty) {
                 mergedData['items'] = preservedItems.map((item) => item.toJson()).toList();
              }
              _orders[orderIndex] = OrderModel.fromJson(mergedData);
            } else {
              _orders[orderIndex] = OrderModel(
                id: _orders[orderIndex].id,
                userId: _orders[orderIndex].userId,
                status: updateData['new_status'] as String,
                totalAmount: _orders[orderIndex].totalAmount,
                subtotal: _orders[orderIndex].subtotal,
                gstAmount: _orders[orderIndex].gstAmount,
                deliveryCharge: _orders[orderIndex].deliveryCharge,
                invoiceRequired: _orders[orderIndex].invoiceRequired,
                items: _orders[orderIndex].items,
                createdAt: _orders[orderIndex].createdAt,
                updatedAt: _orders[orderIndex].updatedAt,
                customerName: _orders[orderIndex].customerName,
                customerPhone: _orders[orderIndex].customerPhone,
                customerEmail: _orders[orderIndex].customerEmail,
                deliveryAddress: _orders[orderIndex].deliveryAddress,
                paymentMethod: _orders[orderIndex].paymentMethod,
                paymentStatus: _orders[orderIndex].paymentStatus,
                deliveredAt: _orders[orderIndex].deliveredAt,
                statusNotes: _orders[orderIndex].statusNotes,
                notes: _orders[orderIndex].notes,
                gstNumber: _orders[orderIndex].gstNumber,
                estimatedDelivery: _orders[orderIndex].estimatedDelivery,
                trackingMilestones: _orders[orderIndex].trackingMilestones,
                paymentDueDate: _orders[orderIndex].paymentDueDate,
                paymentSource: _orders[orderIndex].paymentSource,
                paymentDueDays: _orders[orderIndex].paymentDueDays,
                transactionId: _orders[orderIndex].transactionId,
              );
            }
          });
          
          if (updateData['status_changed'] == true || updateData['type'] == 'status_update') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order updated to ${updateData['new_status']}'),
                backgroundColor: _indigo,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          _loadOrders();
        }
      }
    });
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final orders = await _orderService.getUserOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });

      if (OrdersScreen.pendingOrderId != null && mounted) {
        final pendingId = OrdersScreen.pendingOrderId;
        OrdersScreen.pendingOrderId = null;
        try {
          final order = orders.firstWhere((o) => o.id == pendingId);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _viewOrderDetails(order);
          });
        } catch (e) {
          print('Pending order $pendingId not found');
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      if (mounted) SupabaseService.handleServiceError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_indigo, _indigoLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Orders',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        Text(
                          _isLoading
                              ? 'Loading...'
                              : '${_orders.length} order${_orders.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _slate500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadOrders,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          size: 20, color: _slate500),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: RefreshIndicator(
                color: _indigo,
                onRefresh: _loadOrders,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getItemDisplayName(OrderItemModel item, OrderModel order) {
    // 1. Try the item's own product name, but ignore generic quote defaults
    var name = item.productName.trim();
    if (name.isNotEmpty && !name.contains('Quote Item')) {
      return name;
    }

    // 2. Try falling back to the quality option (which often holds the Brand in quotes)
    if (item.qualityOptionName.isNotEmpty &&
        !item.qualityOptionName.toLowerCase().contains('quote')) {
      return item.qualityOptionName;
    }

    // 3. Try finding *any* other item in the same order that has a valid name
    for (final other in order.items) {
      final otherName = other.productName.trim();
      if (otherName.isNotEmpty && !otherName.contains('Quote Item')) {
        return otherName;
      }
    }

    // 4. Ultimate fallback to whatever was there
    return name.isNotEmpty ? name : 'Product';
  }

  Widget _buildBody() {
    if (_isGuest) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _indigo.withValues(alpha: 0.12),
                    _indigoLight.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 40, color: _indigo),
            ),
            const SizedBox(height: 20),
            const Text(
              'Login Required',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
            ),
            const SizedBox(height: 8),
            Text('Log in to view and track your orders',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Login to Continue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _indigo));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 36, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load orders',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _indigo.withValues(alpha: 0.12),
                    _indigoLight.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 40, color: _indigo),
            ),
            const SizedBox(height: 20),
            const Text('No orders yet',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
            const SizedBox(height: 8),
            Text('Start shopping to see your orders here',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    // Find credit orders that need a transaction ID
    final ordersNeedingTxnId = _orders.where((o) {
      final isCredit = (o.paymentSource == 'credit') ||
          (o.paymentMethod?.toLowerCase().contains('credit') ?? false);
      final notPaid = o.paymentStatus?.toLowerCase() != 'paid';
      final noTxn = o.transactionId == null || o.transactionId!.isEmpty;
      return isCredit && notPaid && noTxn;
    }).toList();

    return ListView.builder(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _orders.length + (ordersNeedingTxnId.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Show transaction ID alert as first item
        if (ordersNeedingTxnId.isNotEmpty && index == 0) {
          return _buildTxnIdAlertBanner(ordersNeedingTxnId.length);
        }
        final orderIndex = ordersNeedingTxnId.isNotEmpty ? index - 1 : index;
        final order = _orders[orderIndex];
        return _buildOrderCard(order);
      },
    );
  }

  /// Orange alert banner at top of list when any credit order is missing a transaction ID.
  Widget _buildTxnIdAlertBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_outlined,
                size: 18, color: Color(0xFFEA580C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Required: Submit Transaction ID',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count credit order${count == 1 ? '' : 's'} pending bank transfer confirmation. '  
                  'Open the order → Submit Transaction ID.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEA580C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = _getStatusColor(order.status, transactionId: order.transactionId);
    final statusText = _getStatusText(order.status, transactionId: order.transactionId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Order items
            ...order.items.take(2).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      // Product thumbnail – 44×44 with graceful fallback
                      Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF1F5F9),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: (item.imageUrl != null &&
                                  item.imageUrl!.isNotEmpty)
                              ? Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _indigo.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        size: 22,
                                        color: _indigo.withValues(alpha: 0.4),
                                      ),
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.inventory_2_outlined,
                                  size: 22,
                                  color: _indigo.withValues(alpha: 0.4),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getItemDisplayName(item, order),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _dark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${item.unitPrice.toStringAsFixed(0)} / ${item.unit ?? 'unit'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'x${item.quantity.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (order.items.length > 2)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                  '+${order.items.length - 2} more',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[400]),
                ),
              ),

            const SizedBox(height: 16),
            
            // Payment Due Date Display — shows admin-set window + deadline
            if (order.paymentDueDate != null &&
                order.paymentStatus?.toLowerCase() != 'paid')
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final due = order.paymentDueDate!;
                  final dueDate = DateTime(due.year, due.month, due.day);
                  final diff = dueDate.difference(today).inDays;

                  String text;
                  Color color;
                  IconData icon;

                  if (diff < 0) {
                    text = 'Payment Overdue by ${-diff} day${-diff == 1 ? '' : 's'}';
                    color = const Color(0xFFDC2626);
                    icon = Icons.error_outline_rounded;
                  } else if (diff == 0) {
                    text = 'Payment Due TODAY';
                    color = const Color(0xFFC2410C);
                    icon = Icons.warning_amber_rounded;
                  } else if (diff <= 5) {
                    text = 'Payment Due in $diff day${diff == 1 ? '' : 's'} — ${_formatDate(dueDate)}';
                    color = const Color(0xFFEA580C);
                    icon = Icons.schedule_rounded;
                  } else {
                    text = 'Pay by ${_formatDate(dueDate)}';
                    color = const Color(0xFF2563EB);
                    icon = Icons.event_available_rounded;
                  }

                  // Sub-label: shows the admin-set window
                  final windowLabel = order.paymentDueDays != null
                      ? '${order.paymentDueDays}-day payment window'
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              if (windowLabel != null)
                                Text(
                                  windowLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Divider
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Bottom: Date + Total + Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(order.createdAt),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _viewOrderDetails(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _indigo,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Details',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _trackOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Track',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, {String? transactionId}) {
    if (status.toLowerCase() == 'pending') {
      if (transactionId != null && transactionId.isNotEmpty) {
        return const Color(0xFFF59E0B); // Amber
      }
      return const Color(0xFF6B7280); // Slate
    }
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'processing':
        return const Color(0xFFF59E0B);
      case 'shipped':
      case 'in_transport':
        return const Color(0xFF3B82F6);
      case 'delivered':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(String status, {String? transactionId}) {
    if (status.toLowerCase() == 'pending') {
      if (transactionId != null && transactionId.isNotEmpty) {
        return 'Awaiting Confirmation';
      }
      return 'Waiting for Payment';
    }
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'in_transport':
        return 'In Transport';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _viewOrderDetails(OrderModel order) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(order: order)));
  }

  void _trackOrder(OrderModel order) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(order: order)));
  }
}
