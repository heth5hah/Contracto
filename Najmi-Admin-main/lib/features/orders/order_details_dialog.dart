import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import 'order_model.dart';
import 'orders_provider.dart';
import '../../core/services/order_pdf_service.dart';
import '../../core/services/admin_notification_service.dart';
import '../returns/returns_provider.dart';
import '../../core/services/admin_razorpay_service.dart';

class OrderDetailsDialog extends ConsumerStatefulWidget {
  final Order order;

  const OrderDetailsDialog({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends ConsumerState<OrderDetailsDialog> {
  static const List<String> _allowedStatuses = [
    'pending',
    'confirmed',
    'processing',
    'in_transport',
    'delivered',
    'completed',
    'cancelled',
    'returned',
  ];

  late String _currentStatus;
  bool _isUpdating = false;
  List<ReturnRequest> _orderReturns = [];
  bool _isLoadingReturns = false;

  @override
  void initState() {
    super.initState();
    final rawStatus = widget.order.status?.toLowerCase();
    if (rawStatus != null && _allowedStatuses.contains(rawStatus)) {
      _currentStatus = rawStatus;
    } else {
      // Fallback to a safe default so the dropdown always has a valid value
      _currentStatus = 'pending';
    }
    
    // Load initial returns
    _loadReturns();
    
    // Set up real-time listener for returns
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeListener();
    });
  }

  void _setupRealtimeListener() {
    final service = ref.read(adminNotificationServiceProvider);
    
    // Listen to new return requests (from mobile app) - PRIMARY LISTENER
    service.newReturnsStream.listen((returnData) {
      final returnOrderId = returnData['order_id'] as String?;
      
      print('🔄 New return event received in order details: order_id=$returnOrderId, current_order=${widget.order.id}');
      
      // If this return is for the current order, refresh returns IMMEDIATELY
      if (returnOrderId == widget.order.id && mounted) {
        print('✅✅✅ MATCH! New return is for current order - refreshing immediately');
        
        // Show notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New return request received for this order',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Refresh returns immediately (no delay)
        _loadReturns();
        
        // Also invalidate orders to refresh the list view
        ref.invalidate(ordersProvider);
        ref.invalidate(ordersWithRealtimeProvider);
      }
    });
    
    // Listen to order status updates (for has_return changes)
    service.orderStatusUpdatedStream.listen((updateData) {
      if (updateData['entity_id'] == widget.order.id && mounted) {
        final hasReturnChanged = updateData['has_return_changed'] == true;
        if (hasReturnChanged) {
          print('🔄 has_return changed for current order - refreshing returns');
          _loadReturns();
        }
      }
    });
    
    // Listen to return status updates
    service.returnStatusUpdatedStream.listen((updateData) {
      if (updateData['order_id'] == widget.order.id && mounted) {
        print('🔄 Return status updated in real-time for order ${widget.order.id}');
        _loadReturns();
      }
    });
  }

  Future<void> _loadReturns() async {
    if (mounted) {
      setState(() {
        _isLoadingReturns = true;
      });
    }
    
    final returns = await _fetchOrderReturns();
    
    if (mounted) {
      setState(() {
        _orderReturns = returns;
        _isLoadingReturns = false;
      });
    }
  }

  Future<List<ReturnRequest>> _fetchOrderReturns() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final orderId = widget.order.id;
      
      print('========================================');
      print('FETCHING RETURNS FOR ORDER');
      print('========================================');
      print('Order ID: $orderId');
      print('Order Status: ${widget.order.status}');
      print('Customer: ${widget.order.customerName}');
      
      // First, let's check if there are ANY returns in the database
      final allReturnsCheck = await supabase
          .from('returns')
          .select('id, order_id, return_status')
          .limit(5);
      
      print('Total returns in DB (sample): $allReturnsCheck');
      
      // Now fetch returns for this specific order
      // Try with explicit RLS bypass check
      final response = await supabase
          .from('returns')
          .select('*, return_items(*)')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);
      
      // If empty, check if it's an RLS issue
      if (response.isEmpty) {
        print('⚠️ No returns found - checking RLS and admin access...');
        
        // Check if user is admin
        try {
          final userCheck = await supabase
              .from('users')
              .select('id, role')
              .eq('id', supabase.auth.currentUser?.id ?? '')
              .maybeSingle();
          
          print('Current user check: $userCheck');
          print('User role: ${userCheck?['role']}');
          print('Current user ID: ${supabase.auth.currentUser?.id}');
          
          if (userCheck?['role'] != 'admin') {
            print('❌ User is NOT admin! Role: ${userCheck?['role']}');
            print('⚠️ Run this SQL: UPDATE users SET role = \'admin\' WHERE id = \'${supabase.auth.currentUser?.id}\';');
          } else {
            print('✅ User is admin, but returns still not showing - RLS policy issue');
          }
        } catch (e) {
          print('Error checking user role: $e');
        }
      }

      print('Returns query response for order $orderId: $response');
      print('Number of returns found: ${response.length}');

      if (response.isEmpty) {
        print('⚠️ No returns found for order $orderId');
        print('Checking if order ID format matches...');
        
        // Try to find returns by customer name as fallback
        if (widget.order.customerName != null) {
          final customerReturns = await supabase
              .from('returns')
              .select('*, orders!inner(customer_name), return_items(*)')
              .eq('orders.customer_name', widget.order.customerName!)
              .order('created_at', ascending: false)
              .limit(5);
          
          print('Returns for customer ${widget.order.customerName}: $customerReturns');
        }
      }

      final returns = <ReturnRequest>[];
      for (var returnData in response) {
        final itemsData = returnData['return_items'] as List? ?? [];
        final items = itemsData
            .map((item) => ReturnItem.fromJson(item as Map<String, dynamic>))
            .toList();
        returns.add(ReturnRequest.fromJson(returnData, items: items));
      }
      
      print('✅ Parsed ${returns.length} returns successfully');
      print('========================================');
      
      return returns;
    } catch (e, stackTrace) {
      print('❌ ERROR fetching returns: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading returns: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Check Console',
              onPressed: () {},
            ),
          ),
        );
      }
      return [];
    }
  }

  /// Calculate refund amount automatically from return items.
  /// Refund policy:
  ///   - Full product/item amount is refunded.
  ///   - 5% of the GST amount is refunded (the portion charged to the customer).
  ///   - Transport / delivery charges are NOT refundable.
  Future<Map<String, dynamic>> _calculateRefundAmount(ReturnRequest returnReq) async {
    try {
      final supabase = ref.read(supabaseProvider);

      // Get order details to calculate proportional GST
      final orderData = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', returnReq.orderId)
          .single();

      // Read from order_items table first, fall back to orders.items JSONB array
      List<dynamic> orderItems = (orderData['order_items'] as List? ?? []) as List<dynamic>;
      if (orderItems.isEmpty && orderData['items'] != null) {
        if (orderData['items'] is List) {
          orderItems = orderData['items'] as List<dynamic>;
        } else if (orderData['items'] is String) {
          try {
            orderItems = jsonDecode(orderData['items'] as String) as List<dynamic>;
          } catch (_) {}
        }
      }

      // Returned items product total
      final double returnedItemsTotal =
          returnReq.items.fold(0.0, (sum, item) => sum + item.totalPrice);

      // All order items subtotal (used to calculate proportion)
      double orderItemsTotal = orderItems.fold(0.0, (sum, item) {
        final itemTotal = (item['total_price'] as num?)?.toDouble() ?? 
                          (item['totalPrice'] as num?)?.toDouble() ?? 0.0;
        return sum + itemTotal;
      });

      // Check if full order is being returned
      final int totalOrderQuantity =
          orderItems.fold(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0));
      final double totalReturnedQuantity =
          returnReq.items.fold(0.0, (sum, item) => sum + item.quantity);
      final bool isFullOrderReturn = totalReturnedQuantity >= totalOrderQuantity;

      // -----------------------------------------------------------------
      // Refund policy:
      //   • Full product/item amount is refunded.
      //   • The stored gst_amount IS the 5% GST charged to the customer.
      //     A proportional slice of that is refunded for returned items.
      //   • Transport/delivery charges are NOT refundable under any condition.
      // -----------------------------------------------------------------
      double orderGst = 0.0;
      if (orderData['gst_amount'] != null) {
        // gst_amount is already the GST figure charged on the whole order
        orderGst = (orderData['gst_amount'] as num).toDouble();
      } else if (orderData['tax_amount'] != null) {
        orderGst = (orderData['tax_amount'] as num).toDouble();
      } else if (orderItemsTotal > 0) {
        // Fallback: calculate 18% GST on items subtotal
        orderGst = orderItemsTotal * 0.18;
      }

      // Proportional GST slice for the returned items
      double proportionalGst = 0.0;
      if (orderItemsTotal > 0) {
        final returnRatio = returnedItemsTotal / orderItemsTotal;
        // The stored gst_amount is the full 5% GST; refund the proportional share
        proportionalGst = orderGst * returnRatio;
      }

      // Delivery / transport is NEVER refunded
      const double deliveryRefund = 0.0;
      final double orderDelivery = orderData['delivery_charge'] != null
          ? (orderData['delivery_charge'] as num).toDouble()
          : orderData['shipping_charges'] != null
              ? (orderData['shipping_charges'] as num).toDouble()
              : 0.0;

      // Final refund: (product total + GST portion) minus 5% deduction fee
      final double refundAmount = (returnedItemsTotal + proportionalGst) * 0.95;

      return {
        'refund_amount': refundAmount,
        'items_total': returnedItemsTotal,
        'gst_5pct': proportionalGst,
        'delivery_charge': orderDelivery, // shown as non-refundable info
        'delivery': deliveryRefund,       // always 0 – not refunded
        'is_full_return': isFullOrderReturn,
      };
    } catch (e) {
      print('Error calculating refund: $e');
      // Fallback: use return items total only
      final itemsTotal = returnReq.items.fold(0.0, (sum, item) => sum + item.totalPrice);
      return {
        'refund_amount': itemsTotal,
        'items_total': itemsTotal,
        'gst_5pct': 0.0,
        'delivery_charge': 0.0,
        'delivery': 0.0,
        'is_full_return': false,
      };
    }
  }

  Future<void> _processRefund(ReturnRequest returnReq) async {
    // Check if refund already processed - prevent duplicate refunds
    if (returnReq.returnStatus == 'completed') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund of ₹${returnReq.refundAmount.toStringAsFixed(2)} has already been processed'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Allow refund for approved returns and any further progress stages
    const refundEligibleStatuses = {
      'approved',
      'pickup_scheduled',
      'picked_up',
      'product_received',
      'refund_pending',
    };
    if (!refundEligibleStatuses.contains(returnReq.returnStatus)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return must be approved before processing refund'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Calculate refund amount
    final refundCalculation = await _calculateRefundAmount(returnReq);
    final refundAmount = refundCalculation['refund_amount'] as double;
    final itemsTotal = refundCalculation['items_total'] as double;
    final gst5pct = refundCalculation['gst_5pct'] as double;
    final deliveryCharge = refundCalculation['delivery_charge'] as double;
    final isFullReturn = refundCalculation['is_full_return'] as bool;

    // Controllers for the input fields
    final refundRefIdController = TextEditingController();
    final refundNotesController = TextEditingController();
    String selectedPaymentMode = 'App Wallet';
    final formKey = GlobalKey<FormState>();

    // Show confirmation dialog with breakdown and inputs
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Process Refund'),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Refund Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${refundAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Breakdown:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildRefundBreakdownRow('Items Subtotal', itemsTotal),
                if (gst5pct > 0)
                  _buildRefundBreakdownRow('Proportionate GST', gst5pct),
                _buildRefundBreakdownRow(
                  '5% Deduction Fee',
                  -(itemsTotal + gst5pct) * 0.05,
                  note: '(-5%)',
                ),
                if (deliveryCharge > 0)
                  _buildRefundBreakdownRow(
                    'Transport/Delivery',
                    deliveryCharge,
                    note: '(Non-refundable)',
                    isStrikethrough: true,
                  ),
                const Divider(height: 24),
                
                const Text(
                  'Transaction Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                
                if (widget.order.paymentId != null)
                  Container(
                     margin: const EdgeInsets.only(bottom: 16),
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.orange[50],
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.orange[200]!),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                            Icon(Icons.auto_fix_high, size: 16, color: Colors.orange[800]),
                            const SizedBox(width: 8),
                            Text('Automated Refund Available', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange[900])),
                           ],
                         ),
                         const SizedBox(height: 8),
                         Text('Original Payment ID: ${widget.order.paymentId}',
                          style: TextStyle(fontSize: 12, color: Colors.orange[900])),
                         const SizedBox(height: 12),
                          Row(
                           children: [
                             Checkbox(
                               value: selectedPaymentMode == 'Razorpay (Auto)',
                               onChanged: (val) {
                                  // Update state using state setter from StatefulBuilder if we were in one, 
                                  // but here we are in showDialog builder.
                                  // We need to use StatefulBuilder for the dialog content to update UI
                                  // For now, let's just use the Dropdown below to select it.
                               },
                             ),
                              Expanded(
                               child: Text('Use Auto-Refund via Razorpay', style: TextStyle(fontSize: 13)),
                             ),
                           ],
                         ),
                       ],
                     ),
                  ),

                // Payment Mode Dropdown
                DropdownButtonFormField<String>(
                  value: selectedPaymentMode,
                  decoration: InputDecoration(
                    labelText: 'Payment Mode',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [
                   if (widget.order.paymentId != null) 
                     const DropdownMenuItem(value: 'Razorpay (Auto)', child: Text('Razorpay (Auto-Refund)')),
                   const DropdownMenuItem(value: 'App Wallet', child: Text('App Wallet (Store Credit)')),
                   ...['UPI', 'Bank Transfer', 'Cash', 'Cheque', 'Other']
                      .map((mode) => DropdownMenuItem(value: mode, child: Text(mode))),
                  ].toList(),
                  onChanged: (val) {
                    if (val != null) selectedPaymentMode = val;
                  },
                ),
                const SizedBox(height: 12),
                
                // Transaction Reference ID Input
                TextFormField(
                  controller: refundRefIdController,
                  decoration: InputDecoration(
                    labelText: 'Transaction Ref ID / UPI ID',
                    hintText: 'e.g. UPI Ref Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) {
                    if (selectedPaymentMode != 'App Wallet' && (value == null || value.isEmpty)) {
                      return 'Please enter transaction reference ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Notes Input
                TextFormField(
                  controller: refundNotesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Any additional details...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Refund will be marked as completed and customer notified.',
                          style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Confirm Refund'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    
    // Get values from controllers
    String refundMode = selectedPaymentMode;
    String refundRefId = refundRefIdController.text;
    final notes = refundNotesController.text;

    // Handle Auto-Refund
    if (refundMode == 'Razorpay (Auto)' && widget.order.paymentId != null) {
      // Show loading for refund API
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final result = await AdminRazorpayService.processRefund(
        paymentId: widget.order.paymentId!,
        amount: refundAmount,
      );

      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        refundRefId = result['refund_id'];
        refundMode = 'Razorpay'; // Save as Razorpay in DB
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-Refund Successful! Ref: $refundRefId'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
           // Show error and ask to continue or cancel
           final shouldContinue = await showDialog<bool>(
             context: context, 
             builder: (ctx) => AlertDialog(
               title: const Text('Auto-Refund Failed'),
               content: Text('Reason: ${result['error']}\n\nDo you want to record this as a manual refund instead?'),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                 TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record Manual')),
               ],
             )
           );
           
           if (shouldContinue != true) return;
           
           // If continuing, switch to Manual mode
           refundMode = 'Razorpay (Manual Record)';
        } else {
          return;
        }
      }
    } else if (refundMode == 'App Wallet') {
      refundRefId = 'WALLET-${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      final supabase = ref.read(supabaseProvider);
      
      // Update return with refund processed status
      // ───────────────────────────────────────────────────────────────────────
      // Credit App Wallet if selected
      // ───────────────────────────────────────────────────────────────────────
      if (refundMode == 'App Wallet') {
        try {
          // Check if user is business (has credit_limit > 0) or individual
          final userData = await supabase
              .from('users')
              .select('user_type')
              .eq('id', returnReq.userId)
              .maybeSingle();
          
          final userType = userData?['user_type'] as String? ?? 'individual';
          final isBusiness = userType == 'business';

          if (isBusiness) {
            // Business user: use restore_credit_for_return RPC
            // This checks if order was credit-paid and routes accordingly
            final result = await supabase.rpc('restore_credit_for_return', params: {
              'p_order_id': returnReq.orderId,
              'p_return_id': returnReq.id,
              'p_refund_amount': refundAmount,
              'p_description': 'Refund for return #${returnReq.id.substring(0, 8).toUpperCase()}',
            });

            if (result is Map && result['success'] == true) {
              final destination = result['refund_destination'] ?? 'credit';
              print('✅ Business refund processed: destination=$destination');
              if (destination == 'bank') {
                refundRefId = 'BANK-REFUND-${DateTime.now().millisecondsSinceEpoch}';
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Order was bank-paid. Refund routed to bank. Credit line unchanged.'),
                    backgroundColor: Color(0xFF3B82F6),
                    duration: Duration(seconds: 4),
                  ));
                }
              }
            } else {
              throw Exception(result is Map ? result['error'] : 'RPC failed');
            }
          } else {
            // Individual user: use process_individual_refund RPC
            // This refunds subtotal WITHOUT GST to the wallet
            final result = await supabase.rpc('process_individual_refund', params: {
              'p_order_id': returnReq.orderId,
              'p_return_id': returnReq.id,
              'p_items_subtotal': itemsTotal,  // Full product amount
              'p_gst_amount': gst5pct,         // 5% GST portion to refund
            });

            if (result is Map && result['success'] == true) {
              final walletRefund = result['refund_amount'] as num? ?? refundAmount;
              print('✅ Individual wallet refund: ₹$walletRefund (items ₹$itemsTotal + GST 5% ₹$gst5pct)');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    '₹${walletRefund.toStringAsFixed(2)} refunded to wallet '
                    '(₹${itemsTotal.toStringAsFixed(2)} items + ₹${gst5pct.toStringAsFixed(2)} GST 5%)'),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 4),
                ));
              }
            } else {
              throw Exception(result is Map ? result['error'] : 'Individual refund RPC failed');
            }
          }
        } catch (e) {
          print('Error processing wallet refund: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error crediting App Wallet: $e'),
              backgroundColor: Colors.red,
            ));
          }
          return; // STOP execution if wallet credit fails! Do not mark return as completed.
        }
      }

      // Update return with refund processed status
      // We first update the status which should exist
      await supabase
          .from('returns')
          .update({
            'return_status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', returnReq.id);

      // Update refund tracking columns using actual schema column names
      // This is critical: refund_amount must be written so the app wallet backfill works
      try {
        await supabase
            .from('returns')
            .update({
              'refund_amount': refundAmount,
              'refund_amount_final': refundAmount,
              'refund_transaction_id': refundRefId.isNotEmpty ? refundRefId : null,
              'refund_processed_at': DateTime.now().toIso8601String(),
              'refund_method': refundMode == 'App Wallet' ? 'credit' : 'bank',
            })
            .eq('id', returnReq.id);
        print('✅ Refund tracking columns updated successfully: amount=₹$refundAmount');
      } catch (e) {
        print('❌ Refund column update failed: $e');
        // Try updating just refund_amount as bare minimum for wallet backfill
        try {
          await supabase
              .from('returns')
              .update({'refund_amount': refundAmount, 'refund_amount_final': refundAmount})
              .eq('id', returnReq.id);
          print('✅ Fallback: refund_amount saved successfully');
        } catch (e2) {
          print('❌ Critical: Could not save refund_amount – wallet backfill will be unable to detect this refund: $e2');
        }
      }

      // Update the order's return_status
      final orderUpdateData = {
        'return_status': 'Return Completed',
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Try updating order with refund status
      try {
         await supabase
            .from('orders')
            .update({
              ...orderUpdateData,
              'refund_status': 'Completed',
            })
            .eq('id', returnReq.orderId);
      } catch (e) {
         print('Order refund_status update failed: $e');
         // Fallback: update just the return_status
          await supabase
            .from('orders')
            .update(orderUpdateData)
            .eq('id', returnReq.orderId);
      }

      // Get order number for notification
      final orderNumber = widget.order.orderId ?? returnReq.orderId.substring(0, 8).toUpperCase();

      // Create a notification for the user about refund
      try {
        await supabase.from('notifications').insert({
          'source': 'admin',
          'target': 'user',
          'user_id': returnReq.userId,
          'title': 'Refund Processed',
          'message': '₹${refundAmount.toStringAsFixed(2)} refund processed for Order #$orderNumber',
          'type': 'refund',
          'reference_id': returnReq.orderId,
          'metadata': {
            'return_id': returnReq.id,
            'order_id': returnReq.orderId,
            'refund_amount': refundAmount,
            'order_number': orderNumber,
          },
        });
      } catch (e) {
        print('Error creating refund notification: $e');
      }

      // Refresh orders list
      ref.invalidate(ordersProvider);
      ref.invalidate(ordersWithRealtimeProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Refund of ₹${refundAmount.toStringAsFixed(2)} processed successfully'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
        _loadReturns(); // Refresh returns list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing refund: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildRefundBreakdownRow(
    String label,
    double amount, {
    bool isTotal = false,
    String? note,
    bool isStrikethrough = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  color: isStrikethrough
                      ? Colors.grey[400]
                      : isTotal
                          ? Colors.black87
                          : Colors.grey[700],
                  decoration: isStrikethrough ? TextDecoration.lineThrough : null,
                ),
              ),
              if (note != null) ...[
                const SizedBox(width: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 11,
                    color: isStrikethrough ? Colors.red[400] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          Text(
            isStrikethrough ? '–' : '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isStrikethrough
                  ? Colors.grey[400]
                  : isTotal
                      ? const Color(0xFF10B981)
                      : Colors.grey[700],
              decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateReturnStatus(String returnId, String newStatus) async {
    // Optimistic update: Update local state immediately
    final oldReturns = List<ReturnRequest>.from(_orderReturns);
    final returnIndex = _orderReturns.indexWhere((r) => r.id == returnId);
    if (returnIndex != -1) {
      setState(() {
        _orderReturns[returnIndex] = ReturnRequest(
          id: _orderReturns[returnIndex].id,
          orderId: _orderReturns[returnIndex].orderId,
          userId: _orderReturns[returnIndex].userId,
          returnStatus: newStatus,
          returnReason: _orderReturns[returnIndex].returnReason,
          refundAmount: _orderReturns[returnIndex].refundAmount,
          notes: _orderReturns[returnIndex].notes,
          createdAt: _orderReturns[returnIndex].createdAt,
          updatedAt: DateTime.now(), // Update timestamp
          items: _orderReturns[returnIndex].items,
        );
      });
    }

    try {
      final supabase = ref.read(supabaseProvider);
      
      // First, get the return to find the order_id
      final returnData = await supabase
          .from('returns')
          .select('order_id')
          .eq('id', returnId)
          .single();
      
      final orderId = returnData['order_id'] as String;
      
      // Update the return status
      await supabase
          .from('returns')
          .update({
            'return_status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', returnId);
      
      // Update the order's return_status to match
      final orderReturnStatus = newStatus == 'pending' 
          ? 'Pending Review'
          : newStatus == 'approved'
              ? 'Return Approved'
              : newStatus == 'rejected'
                  ? 'Return Rejected'
                  : newStatus == 'completed'
                      ? 'Return Completed'
                      : 'Pending Review';
      
      final orderUpdateData = <String, dynamic>{
        'return_status': orderReturnStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (newStatus == 'refund_completed' || newStatus == 'completed') {
        orderUpdateData['order_status'] = 'returned';
      }

      await supabase
          .from('orders')
          .update(orderUpdateData)
          .eq('id', orderId);
      
      // Refresh orders list (real-time will also trigger refresh)
      ref.invalidate(ordersProvider);
      ref.invalidate(ordersWithRealtimeProvider);
      
      // Also manually trigger a refresh after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.invalidate(ordersProvider);
          ref.invalidate(ordersWithRealtimeProvider);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return status updated to $newStatus'),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadReturns(); // Refresh returns list to get latest data
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _orderReturns = oldReturns; // Revert to old state
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating return: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final isConfirmingPayment = newStatus == 'confirmed' && widget.order.paymentStatus != 'paid';
    if (_currentStatus == newStatus && !isConfirmingPayment) return;

    // Handle 'in_transport' status with specific details
    if (newStatus == 'in_transport') {
      final transportDetails = await _showTransportDetailsDialog();
      if (transportDetails == null) return; // User cancelled
      
      setState(() {
        _isUpdating = true;
      });

      try {
        final supabase = ref.read(supabaseProvider);
        
        final transportNote = 
            'Transport Mode: ${transportDetails['mode']}\n'
            'Driver: ${transportDetails['driver_name']}\n'
            'Mobile: ${transportDetails['driver_phone']}\n'
            'Delivery Date: ${transportDetails['delivery_date']}';
            
        final Map<String, dynamic> updateData = {
          'order_status': newStatus,
          'status_notes': transportNote,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await supabase
            .from('orders')
            .update(updateData)
            .eq('id', widget.order.id);

        setState(() {
          _currentStatus = newStatus;
          _isUpdating = false;
        });

        // Refresh orders
        ref.invalidate(ordersProvider);
        await Future.delayed(const Duration(milliseconds: 300));
        ref.invalidate(ordersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order marked In Transport with details'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUpdating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: $e')),
          );
        }
      }
      return;
    }

    // Removed dueDays prompt here as requested; handled in Business Billing.

    setState(() {
      _isUpdating = true;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      
      // Build update data
      final Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newStatus == 'confirmed') {
        if (_currentStatus == 'pending') {
          updateData['order_status'] = 'confirmed';
        }
      } else {
        updateData['order_status'] = newStatus;
      }
      
      // Set delivered_at timestamp when marking as delivered
      if (newStatus == 'delivered') {
        updateData['delivered_at'] = DateTime.now().toIso8601String();
        // Kept payment_status change but removed dueDays check
        if (widget.order.paymentSource == 'credit') {
          updateData['payment_status'] = 'pending';
        }
      }

      // Mark payment as paid when order is confirmed
      if (newStatus == 'confirmed') {
        updateData['payment_status'] = 'paid';

        // ── Clear outstanding balance for credit/bank-transfer orders ────────
        final paymentSource = widget.order.paymentSource ?? '';
        final isCreditOrBankOrder = paymentSource == 'credit' ||
            paymentSource == 'credit_clearance' ||
            paymentSource == 'bank_transfer' ||
            (widget.order.paymentMethod ?? '').toLowerCase().contains('credit') ||
            (widget.order.paymentMethod ?? '').toLowerCase().contains('bank transfer');

        if (isCreditOrBankOrder) {
          try {
            final orderAmount = (widget.order.totalAmount ?? 0.0).toDouble();
            final orderId = widget.order.id;

            // 1. Find the user's credit account (by user_id or fallback to email)
            String? resolvedUserId = widget.order.userId;
            if (resolvedUserId == null || resolvedUserId.isEmpty) {
              final userByEmail = await supabase
                  .from('users')
                  .select('id')
                  .eq('email', widget.order.customerEmail ?? '')
                  .maybeSingle();
              resolvedUserId = userByEmail?['id'] as String?;
            }

            final creditAccount = await supabase
                .from('business_credit_accounts')
                .select('id, available_credit, used_credit, credit_limit')
                .eq('user_id', resolvedUserId ?? '')
                .maybeSingle();

            if (creditAccount != null && orderAmount > 0) {
              final accountId = creditAccount['id'] as String;

              // 2. Find the open billing cycle
              final billingCycle = await supabase
                  .from('billing_cycles')
                  .select('id, outstanding_amount, total_payments')
                  .eq('credit_account_id', accountId)
                  .eq('status', 'open')
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();

              if (billingCycle != null) {
                final currentOutstanding =
                    (billingCycle['outstanding_amount'] ?? 0.0).toDouble();
                final currentPayments =
                    (billingCycle['total_payments'] ?? 0.0).toDouble();
                final newOutstanding =
                    (currentOutstanding - orderAmount).clamp(0.0, double.infinity);
                final newPayments = currentPayments + orderAmount;

                // 3. Reduce outstanding_amount in billing cycle
                await supabase.from('billing_cycles').update({
                  'outstanding_amount': newOutstanding,
                  'total_payments': newPayments,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', billingCycle['id']);

                // 4. Close the billing cycle if fully settled
                if (newOutstanding <= 0) {
                  await supabase.from('billing_cycles').update({
                    'status': 'closed',
                    'paid_at': DateTime.now().toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', billingCycle['id']);
                }
              }

              // 5. Restore available credit & reduce used_credit
              final currentAvailable =
                  (creditAccount['available_credit'] ?? 0.0).toDouble();
              final currentUsed =
                  (creditAccount['used_credit'] ?? 0.0).toDouble();
              final creditLimit =
                  (creditAccount['credit_limit'] ?? 0.0).toDouble();
              final newUsed =
                  (currentUsed - orderAmount).clamp(0.0, double.infinity);
              final newAvailable =
                  (creditLimit - newUsed).clamp(0.0, creditLimit);

              final Map<String, dynamic> accountUpdate = {
                'available_credit': newAvailable,
                'used_credit': newUsed,
                'updated_at': DateTime.now().toIso8601String(),
              };

              // If the outstanding balance is now cleared, unfreeze the account!
              if (newUsed <= 0) {
                accountUpdate['is_frozen'] = false;
                accountUpdate['status'] = 'active';
                accountUpdate['freeze_reason'] = null;
                accountUpdate['frozen_at'] = null;
                accountUpdate['unfrozen_at'] = DateTime.now().toIso8601String();
              }

              await supabase.from('business_credit_accounts').update(accountUpdate).eq('id', accountId);

              // 6. Record the credit_usage ledger entry (credit = payment received)
              await supabase.from('credit_usage').insert({
                'credit_account_id': accountId,
                'order_id': orderId,        // FK column name in schema
                'transaction_type': 'credit',
                'amount': orderAmount,
                'description':
                    'Payment confirmed by admin for Order #${widget.order.orderId ?? orderId.substring(0, 8).toUpperCase()}',
                'balance_after': newAvailable,
              });

              // 7. Create a credit_payments record for audit trail
              // payment_method must be one of: 'online','bank_transfer','cheque','other'
              await supabase.from('credit_payments').insert({
                'credit_account_id': accountId,
                'billing_cycle_id': billingCycle?['id'],
                'payment_method': 'bank_transfer',
                'amount': orderAmount,
                'payment_status': 'completed',
                'transaction_id': widget.order.transactionId,
                'payment_date': DateTime.now().toIso8601String(),
                'notes':
                    'Payment verified & confirmed by admin for Order #${widget.order.orderId ?? orderId.substring(0, 8).toUpperCase()}',
              });

              // 8. Run recount RPC to atomically sync everything
              try {
                await supabase.rpc('recount_business_credit_balances',
                    params: {'p_account_id': accountId});
              } catch (rpcErr) {
                print('recount RPC error (non-critical): $rpcErr');
              }

              // 9. If this is a credit clearance order, propagate payment verification to all underlying orders/quotes
              if (paymentSource == 'credit_clearance') {
                try {
                  final orderRes = await supabase
                      .from('orders')
                      .select('items')
                      .eq('id', orderId)
                      .single();
                  if (orderRes != null && orderRes['items'] != null) {
                    final itemsList = orderRes['items'] as List<dynamic>;
                    for (final item in itemsList) {
                      if (item is Map) {
                        final originalId = item['original_id'] as String?;
                        final originalType = item['original_type'] as String?;
                        if (originalId != null && originalType != null) {
                          if (originalType == 'order') {
                            await supabase.from('orders').update({
                              'payment_status': 'paid',
                              'order_status': 'completed',
                              'transaction_id': widget.order.transactionId,
                            }).eq('id', originalId);
                          } else if (originalType == 'quote') {
                            await supabase.from('quote_requests').update({
                              'status': 'order_placed',
                              'transaction_id': widget.order.transactionId,
                            }).eq('id', originalId);
                          }
                        }
                      }
                    }
                  }
                } catch (propErr) {
                  print('Error propagating clearance payment verification: $propErr');
                }
              }

              print(
                  '✅ Credit cleared: ₹$orderAmount | New outstanding: ${(billingCycle?['outstanding_amount'] ?? orderAmount) - orderAmount} | New available: $newAvailable');
            }
          } catch (creditErr) {
            // Non-fatal: order is still confirmed, log and continue
            print('⚠️ Could not clear credit balance (non-fatal): $creditErr');
          }
        }
        // ────────────────────────────────────────────────────────────────────
      }
      
      // When marking as 'returned', ensure a return record exists
      // so it shows up in the Returns screen
      if (newStatus == 'returned') {
        updateData['has_return'] = true;
        updateData['return_status'] = 'Pending Review';
        
        // Check if a return record already exists for this order
        final existingReturn = await supabase
            .from('returns')
            .select('id')
            .eq('order_id', widget.order.id)
            .maybeSingle();
        
        if (existingReturn == null) {
          // Fetch user_id from the order (Order model doesn't store it)
          final orderData = await supabase
              .from('orders')
              .select('user_id')
              .eq('id', widget.order.id)
              .single();
          
          // Auto-create a return record so it appears in Returns screen
          await supabase.from('returns').insert({
            'order_id': widget.order.id,
            'user_id': orderData['user_id'],
            'return_status': 'pending',
            'return_reason': 'Admin-initiated return',
            'refund_amount': widget.order.totalAmount ?? 0,
            'description': 'Return initiated by admin via order status change',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          print('✅ Auto-created return record for order ${widget.order.id}');
        }
        
        // DB trigger only allows delivered → returned.
        // If current status is not 'delivered', set to delivered first.
        if (_currentStatus != 'delivered') {
          await supabase
              .from('orders')
              .update({
                'order_status': 'delivered',
                'delivered_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', widget.order.id);
        }
      }
      
      await supabase
          .from('orders')
          .update(updateData)
          .eq('id', widget.order.id);

      setState(() {
        _currentStatus = newStatus;
      });

      // Refresh the orders list - invalidate both providers to ensure refresh
      ref.invalidate(ordersProvider);
      
      // Force a refresh after a small delay to ensure the data is updated
      await Future.delayed(const Duration(milliseconds: 300));
      ref.invalidate(ordersProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        
        // Close the dialog and return true to indicate refresh needed
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<Map<String, String>?> _showTransportDetailsDialog() async {
    final modeController = TextEditingController();
    final driverNameController = TextEditingController();
    final driverPhoneController = TextEditingController();
    final dateController = TextEditingController(); // Or use a date picker
    final formKey = GlobalKey<FormState>();
    DateTime? selectedDate;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Transport Details'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: modeController,
                  decoration: const InputDecoration(
                    labelText: 'Mode of Transport',
                    hintText: 'e.g. Truck, Courier',
                    prefixIcon: Icon(Icons.local_shipping),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: driverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Driver Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: driverPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Driver Mobile',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date of Delivery',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      selectedDate = date;
                      dateController.text = DateFormat('yyyy-MM-dd').format(date);
                    }
                  },
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'mode': modeController.text,
                  'driver_name': driverNameController.text,
                  'driver_phone': driverPhoneController.text,
                  'delivery_date': dateController.text,
                });
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        // Use fixed dimensions for a stable layout in the dialog
        width: 900,
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order Details: ${widget.order.orderId ?? widget.order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: () => OrderPdfService.generateAndDownloadOrderPdf(widget.order),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download Invoice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            
            // Status and Actions
            Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final hasActiveReturn = _orderReturns.any((r) => 
                        !['rejected', 'cancelled', 'completed', 'refund_completed'].contains(r.returnStatus.toLowerCase()));
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<String>(
                          value: _currentStatus,
                          items: _allowedStatuses
                              .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ')),
                                  ))
                              .toList(),
                          onChanged: (_isUpdating || hasActiveReturn) ? null : (val) {
                            if (val != null) _updateStatus(val);
                          },
                        ),
                        if (hasActiveReturn) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Order status locked: Active return request exists',
                            child: Icon(Icons.lock_outline, size: 16, color: Colors.orange[700]),
                          ),
                        ],
                        if (_isUpdating) ...[
                          const SizedBox(width: 16),
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Area - Expanded to take remaining space
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Info & Summary
                  Expanded(
                    flex: 2,
                    child: Container( // Wrap in Container or SizedBox for constraints if needed
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentStatus == 'pending' ||
                                ((widget.order.paymentSource == 'credit' ||
                                  widget.order.paymentSource == 'credit_clearance' ||
                                  widget.order.paymentSource == 'bank_transfer' ||
                                  (widget.order.paymentMethod ?? '').toLowerCase().contains('credit') ||
                                  (widget.order.paymentMethod ?? '').toLowerCase().contains('bank transfer')) &&
                                 widget.order.paymentStatus != 'paid')) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                      ? Colors.amber[50]
                                      : Colors.blue[50],
                                  border: Border.all(
                                    color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                        ? Colors.amber[300]!
                                        : Colors.blue[200]!,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                              ? Icons.receipt_long
                                              : Icons.hourglass_top_rounded,
                                          color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                              ? Colors.amber[800]
                                              : Colors.blue[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                                ? 'Transaction ID Submitted — Verify & Confirm'
                                                : 'Awaiting Payment from Customer',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                                  ? Colors.amber[900]
                                                  : Colors.blue[800],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Transaction ID display
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                              ? Colors.amber[200]!
                                              : Colors.blue[100]!,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.tag,
                                            size: 14,
                                            color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                                ? Colors.amber[700]
                                                : Colors.blue[400],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'UTR / Transaction ID: ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                                  ? widget.order.transactionId!
                                                  : 'N/A — Not submitted yet',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                                    ? Colors.amber[900]
                                                    : Colors.grey[500],
                                                fontStyle: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                                    ? FontStyle.normal
                                                    : FontStyle.italic,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                          ? 'Verify the bank transfer using the ID above, then confirm payment was received.'
                                          : 'Once the customer submits the transaction ID, it will appear here for verification.',
                                      style: TextStyle(
                                        color: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                            ? Colors.amber[800]
                                            : Colors.blue[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _isUpdating ? null : () => _updateStatus('confirmed'),
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: Text(
                                          widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                              ? 'Confirm Payment Received'
                                              : 'Confirm Order (Skip Payment Check)',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF64748B),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Text('Customer Information',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.person, 'Name', widget.order.customerName ?? 'N/A'),
                            _buildInfoRow(Icons.email, 'Email', widget.order.customerEmail ?? 'N/A'),
                            _buildInfoRow(Icons.phone, 'Phone', widget.order.customerPhone ?? 'N/A'),
                            const SizedBox(height: 24),
                            const Text('Order Summary',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.calendar_today, 'Date', dateFormat.format(widget.order.createdAt)),
                            _buildInfoRow(Icons.local_shipping, 'Delivery', widget.order.deliveryType == 'pickup_from_shop' ? 'Pickup from Shop' : 'Home Delivery'),
                            _buildInfoRow(Icons.payments, 'Total Amount', currencyFormat.format(widget.order.totalAmount ?? 0)),
                            _buildInfoRow(
                              Icons.receipt_long,
                              'Transaction ID',
                              (widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty)
                                  ? widget.order.transactionId!
                                  : 'N/A',
                              valueColor: (widget.order.transactionId != null && widget.order.transactionId!.isNotEmpty)
                                  ? const Color(0xFF10B981)
                                  : Colors.grey[400],
                            ),
                            if (widget.order.paymentSource != null && widget.order.paymentSource!.isNotEmpty)
                              _buildInfoRow(Icons.account_balance, 'Payment Source', widget.order.paymentSource == 'credit' ? 'Business Credit Line' : widget.order.paymentSource!.replaceAll('_', ' ').toUpperCase()),
                            if (widget.order.paymentDueDate != null)
                              _buildInfoRow(Icons.event_available, 'Payment Due Date', dateFormat.format(widget.order.paymentDueDate!), valueColor: Colors.orange[800]),
                            if (widget.order.statusNotes != null) ...[
                              const SizedBox(height: 16),
                              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(widget.order.statusNotes!),
                            ],
                            // Return Requests Section (Real-time)
                            if (_isLoadingReturns && _orderReturns.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 24),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else if (_orderReturns.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      const Text('Return Requests',
                                          style: TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_orderReturns.length}',
                                          style: const TextStyle(
                                            color: Color(0xFF8B5CF6),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ..._orderReturns.map((returnReq) => _buildReturnCard(returnReq)),
                                ],
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Order Items
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Items',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Expanded(
                          child: widget.order.items == null || widget.order.items!.isEmpty
                              ? const Center(child: Text('No items found'))
                              : ListView.builder(
                                  itemCount: widget.order.items!.length,
                                  itemBuilder: (context, index) {
                                    final item = widget.order.items![index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          side: BorderSide(color: Colors.grey[200]!),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            if (item.productImage != null)
                                              Container(
                                                width: 60,
                                                height: 60,
                                                margin: const EdgeInsets.only(right: 16),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  image: DecorationImage(
                                                    image: NetworkImage(item.productImage!),
                                                    fit: BoxFit.cover,
                                                    onError: (_, __) {},
                                                  ),
                                                  color: Colors.grey[100],
                                                ),
                                                child: item.productImage == null ? const Icon(Icons.image, color: Colors.grey) : null,
                                              ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.productName ?? 'Unknown Product',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14),
                                                  ),
                                                  if (item.sku != null)
                                                    Text('SKU: ${item.sku}',
                                                        style: TextStyle(
                                                            color: Colors.grey[600],
                                                            fontSize: 12)),
                                                  const SizedBox(height: 4),
                                                  // Returnable badge (from quote is_returnable flag)
                                                  Builder(builder: (ctx) {
                                                    final returnable = item.isReturnable;
                                                    if (returnable == null) return const SizedBox.shrink();
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: returnable
                                                            ? const Color(0xFF10B981).withOpacity(0.1)
                                                            : const Color(0xFFEF4444).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                          color: returnable
                                                              ? const Color(0xFF10B981).withOpacity(0.5)
                                                              : const Color(0xFFEF4444).withOpacity(0.5),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            returnable ? Icons.undo : Icons.block,
                                                            size: 10,
                                                            color: returnable
                                                                ? const Color(0xFF10B981)
                                                                : const Color(0xFFEF4444),
                                                          ),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            returnable ? 'Returnable' : 'Non-Returnable',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: returnable
                                                                  ? const Color(0xFF10B981)
                                                                  : const Color(0xFFEF4444),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${item.quantity.truncateToDouble() == item.quantity ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} ${item.unit ?? ''} x ${currencyFormat.format(item.unitPrice)}',
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                                Text(
                                                  currencyFormat.format(item.totalPrice),
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(value,
                    style: TextStyle(fontWeight: FontWeight.w500, color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(ReturnRequest returnReq) {
    final statusColor = _getReturnStatusColor(returnReq.returnStatus);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      returnReq.statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${returnReq.refundAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('MMM dd, yyyy').format(returnReq.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          if (returnReq.returnReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${returnReq.returnReason}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
          if (returnReq.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...returnReq.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${item.productName} (Qty: ${item.quantity.truncateToDouble() == item.quantity ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} ${item.unit ?? ''}) - ₹${item.totalPrice.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            )),
          ],
          // ── BANK DETAILS ─────────────────────────────────────────────────
          if (['approved', 'pickup_scheduled', 'picked_up', 'product_received',
              'refund_pending', 'refund_completed'].contains(returnReq.returnStatus)) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchBankDetails(returnReq.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Loading bank details...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  );
                }
                final bank = snap.data;
                if (bank == null) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.pending_actions, size: 14, color: Color(0xFFF59E0B)),
                      SizedBox(width: 6),
                      Expanded(child: Text('Waiting for customer bank details',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)))),
                    ]),
                  );
                }
                final accNum = bank['account_number'] as String? ?? '';
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.account_balance, size: 13, color: Color(0xFF3B82F6)),
                        SizedBox(width: 5),
                        Text('Bank Details ✔',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                      ]),
                      const SizedBox(height: 8),
                      _bankRow('Account Holder', bank['account_holder_name'] ?? '-'),
                      _bankRow('Bank', bank['bank_name'] ?? '-'),
                      Row(children: [
                        SizedBox(width: 90, child: Text('Account No.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                        Text(accNum,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                letterSpacing: 1.2, color: Color(0xFF1E293B))),
                      ]),
                      _bankRow('IFSC', bank['ifsc_code'] ?? '-'),
                      if ((bank['upi_id'] as String?)?.isNotEmpty == true)
                        _bankRow('UPI ID', bank['upi_id'] as String),
                    ],
                  ),
                );
              },
            ),
          ],

          // ── PICKUP TRACKER ───────────────────────────────────────────────
          if (['pickup_scheduled', 'picked_up', 'product_received',
              'refund_pending', 'refund_completed'].contains(returnReq.returnStatus)) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text('Pickup Progress',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            _pickupStepRow('Pickup Scheduled', true, Icons.calendar_today, false),
            _pickupStepRow(
              'Picked Up from Customer',
              ['picked_up','product_received','refund_pending','refund_completed'].contains(returnReq.returnStatus),
              Icons.local_shipping,
              false,
              isCurrent: returnReq.returnStatus == 'pickup_scheduled',
            ),
            _pickupStepRow(
              'Product Received at Warehouse',
              ['product_received','refund_pending','refund_completed'].contains(returnReq.returnStatus),
              Icons.inventory_2,
              true,
              isCurrent: returnReq.returnStatus == 'picked_up',
            ),
          ],

          // ── REFUND ACTIONS ───────────────────────────────────────────────
          if (returnReq.returnStatus == 'approved') ...[
            const SizedBox(height: 12),
            // Refund breakdown section
            FutureBuilder<Map<String, dynamic>>(
              future: _calculateRefundAmount(returnReq),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                
                final calculation = snapshot.data ?? {};
                final refundAmount = (calculation['refund_amount'] as num?)?.toDouble() ?? returnReq.refundAmount;
                final itemsTotal = (calculation['items_total'] as num?)?.toDouble() ?? 0.0;
                final gst5pct = (calculation['gst_5pct'] as num?)?.toDouble() ?? 0.0;
                final deliveryCharge = (calculation['delivery_charge'] as num?)?.toDouble() ?? 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Refund amount display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calculate, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text(
                                'Refund Amount (Auto-calculated)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${refundAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          if (itemsTotal > 0 || gst5pct > 0) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            _buildRefundBreakdownRow('Items Subtotal', itemsTotal),
                            if (gst5pct > 0)
                              _buildRefundBreakdownRow('Proportionate GST', gst5pct),
                            _buildRefundBreakdownRow(
                              '5% Deduction Fee',
                              -(itemsTotal + gst5pct) * 0.05,
                              note: '(-5%)',
                            ),
                            if (deliveryCharge > 0)
                              _buildRefundBreakdownRow(
                                'Transport/Delivery',
                                deliveryCharge,
                                note: '(Non-refundable)',
                                isStrikethrough: true,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Refund button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _processRefund(returnReq),
                        icon: const Icon(Icons.payment, size: 18),
                        label: Text('Process Refund (₹${refundAmount.toStringAsFixed(2)})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else if (returnReq.returnStatus == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateReturnStatus(returnReq.id, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateReturnStatus(returnReq.id, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ] else if (returnReq.returnStatus == 'refund_pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _processRefund(returnReq),
                icon: const Icon(Icons.payments, size: 18),
                label: Text('Process Refund (\u20b9${returnReq.refundAmount.toStringAsFixed(2)})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ] else if (['completed', 'refund_completed'].contains(returnReq.returnStatus)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Refund Completed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          '₹${returnReq.refundAmount.toStringAsFixed(2)} refunded',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchBankDetails(String returnId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('return_bank_details')
          .select()
          .eq('return_id', returnId)
          .maybeSingle();
      return response as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Widget _bankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 90,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
      ]),
    );
  }

  Widget _pickupStepRow(String label, bool done, IconData icon, bool isLast,
      {bool isCurrent = false}) {
    final color = done
        ? const Color(0xFF10B981)
        : isCurrent ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: color.withOpacity(done || isCurrent ? 0.15 : 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: done ? 0 : 1.5),
          ),
          child: Icon(done ? Icons.check : icon, color: color, size: 11),
        ),
        if (!isLast)
          Container(width: 1.5, height: 18,
              color: done ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
      ]),
      const SizedBox(width: 8),
      Padding(
        padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 6),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: done || isCurrent ? FontWeight.w600 : FontWeight.normal,
                color: done
                    ? const Color(0xFF10B981)
                    : isCurrent ? const Color(0xFF1E293B) : Colors.grey[400])),
      ),
    ]);
  }

  Color _getReturnStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
