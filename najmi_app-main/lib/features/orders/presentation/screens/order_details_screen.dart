import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/features/orders/data/models/order_model.dart';
import 'package:contracto_app/features/orders/data/models/return_model.dart';
import 'package:contracto_app/features/orders/data/services/return_service.dart';
import 'package:contracto_app/features/orders/presentation/screens/order_tracking_screen.dart';
import 'package:contracto_app/features/orders/presentation/screens/return_request_screen.dart';
import 'package:contracto_app/features/orders/presentation/screens/return_status_screen.dart';
import 'package:contracto_app/shared/widgets/main_navigation.dart';
import 'package:contracto_app/core/services/user_realtime_service.dart';
import 'package:contracto_app/core/services/order_pdf_service.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _returnService = ReturnService();

  String _getItemDisplayName(OrderItemModel item) {
    var name = item.productName.trim();
    if (name.isNotEmpty && !name.contains('Quote Item')) {
      return name;
    }

    if (item.qualityOptionName.isNotEmpty &&
        !item.qualityOptionName.toLowerCase().contains('quote')) {
      return item.qualityOptionName;
    }

    for (final other in _currentOrder.items) {
      final otherName = other.productName.trim();
      if (otherName.isNotEmpty && !otherName.contains('Quote Item')) {
        return otherName;
      }
    }

    return name.isNotEmpty ? name : 'Product';
  }

  final UserRealtimeService _realtimeService = UserRealtimeService();
  StreamSubscription? _orderStatusSubscription;
  StreamSubscription? _returnStatusSubscription;

  bool _canReturn = false;
  bool _isCheckingReturn = true;
  bool _allItemsNonReturnable = false; // true when every item has is_returnable=false
  List<ReturnModel> _returns = [];
  int _remainingDays = -1;
  String _expiryMessage = '';
  bool _isDelivered = false;
  late OrderModel _currentOrder;
  String? _paymentReceiptUrl;
  String? _transactionId;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    // Pre-populate from the model if already loaded
    _transactionId = (widget.order.transactionId != null &&
            !widget.order.transactionId!.startsWith('CREDIT-'))
        ? widget.order.transactionId
        : null;
    _isDelivered = _currentOrder.status == 'delivered';
    _refreshOrder(); // Fetch latest data — also syncs transactionId & paymentDueDays
    _checkReturnEligibility();
    _loadReturns();
    _setupRealtimeListener();
    _loadPaymentReceipt();
  }

  Future<void> _loadTransactionId() async {
    // Kept as a fallback in case _refreshOrder hasn't run yet
    try {
      final row = await SupabaseService.client
          .from('orders')
          .select('transaction_id')
          .eq('id', _currentOrder.id)
          .maybeSingle();
      if (mounted && row != null) {
        final txnId = row['transaction_id'] as String?;
        if (txnId != null && txnId.isNotEmpty && !txnId.startsWith('CREDIT-')) {
          setState(() => _transactionId = txnId);
        } else {
          setState(() => _transactionId = null);
        }
      }
    } catch (e) {
      print('Error loading transaction ID: $e');
    }
  }

  Future<void> _refreshOrder() async {
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('*')
          .eq('id', _currentOrder.id)
          .single();

      if (mounted) {
        setState(() {
          _currentOrder = OrderModel.fromJson(response);
          _isDelivered = _currentOrder.status == 'delivered';
          // Sync transactionId from refreshed model
          if (_currentOrder.transactionId != null &&
              _currentOrder.transactionId!.isNotEmpty &&
              !_currentOrder.transactionId!.startsWith('CREDIT-')) {
            _transactionId = _currentOrder.transactionId;
          } else {
            _transactionId = null;
          }
        });
        _checkReturnEligibility();
      }
    } catch (e) {
      print('Error refreshing order: $e');
    }
  }

  /// Load the admin-uploaded bill URL from the orders table
  Future<void> _loadPaymentReceipt() async {
    try {
      final row = await SupabaseService.client
          .from('orders')
          .select('bill_url')
          .eq('id', _currentOrder.id)
          .maybeSingle();
      if (mounted && row != null) {
        final billUrl = row['bill_url'] as String?;
        if (billUrl != null && billUrl.isNotEmpty) {
          setState(() => _paymentReceiptUrl = billUrl);
        }
      }
    } catch (e) {
      print('Error loading bill URL: $e');
    }
  }

  Future<void> _openReceiptUrl() async {
    if (_paymentReceiptUrl == null) return;
    final uri = Uri.parse(_paymentReceiptUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _orderStatusSubscription?.cancel();
    _returnStatusSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    // Initialize real-time service
    _realtimeService.initialize();

    // Listen to order status updates for this specific order
    _orderStatusSubscription =
        _realtimeService.orderStatusUpdatedStream.listen((updateData) {
      if (updateData['order_id'] == _currentOrder.id && mounted) {
        final newStatus = updateData['new_status'] as String?;
        if (newStatus != null && newStatus != _currentOrder.status) {
          // Refresh full order to get timestamp updates
          _refreshOrder();

          // Show notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Order status updated to ${newStatus.toUpperCase()}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    // Listen to return status updates for this order
    _returnStatusSubscription =
        _realtimeService.returnStatusUpdatedStream.listen((updateData) {
      if (updateData['order_id'] == _currentOrder.id && mounted) {
        print(
            '🔄 Return status updated in real-time for order ${_currentOrder.id}');
        _loadReturns(); // Refresh returns list
      }
    });
  }

  Future<void> _checkReturnEligibility() async {
    try {
      // Determine up-front if all items are marked non-returnable
      final allNonReturnable =
          _currentOrder.items.isNotEmpty &&
          _currentOrder.items.every((item) => !item.isReturnable);

      final canReturn = await _returnService.canReturnOrder(_currentOrder);
      final remainingDays =
          await _returnService.getRemainingReturnDays(_currentOrder);
      final expiryMessage = await _returnService.getReturnExpiryMessage();

      if (mounted) {
        setState(() {
          _allItemsNonReturnable = allNonReturnable;
          // Force _canReturn to false when all items are non-returnable
          _canReturn = allNonReturnable ? false : canReturn;
          _remainingDays = remainingDays;
          _expiryMessage = expiryMessage;
          _isCheckingReturn = false;
        });
      }
    } catch (e) {
      print('Error checking return eligibility: $e');
      if (mounted) {
        setState(() => _isCheckingReturn = false);
      }
    }
  }

  Future<void> _loadReturns() async {
    try {
      final returns = await _returnService.getOrderReturns(_currentOrder.id);
      if (mounted) {
        setState(() => _returns = returns);
      }
    } catch (e) {
      print('Error loading returns: $e');
    }
  }

  Future<void> _navigateToReturnRequest() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnRequestScreen(order: _currentOrder),
      ),
    );

    if (result == true) {
      // Refresh return status
      _checkReturnEligibility();
      _loadReturns();
    }
  }

  Future<void> _submitTransactionId() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final txnId = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.account_balance_outlined, color: Color(0xFF4F46E5), size: 22),
                SizedBox(width: 10),
                Text('Submit Transaction ID'),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Context card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${_currentOrder.id.replaceAll('-', '').substring(0, 6).toUpperCase()}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8)),
                        ),
                        Text(
                          'Amount: ₹${_currentOrder.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF1E40AF)),
                        ),
                        if (_currentOrder.paymentDueDate != null)
                          Text(
                            'Due: ${DateFormat('dd MMM yyyy').format(_currentOrder.paymentDueDate!)}'
                            '${_currentOrder.paymentDueDays != null ? ' (${_currentOrder.paymentDueDays}d window)' : ''}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF3B82F6)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'After transferring the amount to our bank account, enter the UTR / Reference number here.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Transaction ID / UTR Reference',
                      hintText: 'e.g. UTR12345678',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.tag_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your transaction reference';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, controller.text.trim());
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        });
      },
    );

    if (txnId == null || txnId.isEmpty) return;

    try {
      // First, update the main (combined) order
      await SupabaseService.client.from('orders').update({
        'transaction_id': txnId,
        'payment_status': 'awaiting_confirmation',
      }).eq('id', _currentOrder.id);
      
      // If it's a combined payment/clearance order, propagate the transaction ID
      if (_currentOrder.paymentSource == 'credit_clearance') {
        try {
          final orderRes = await SupabaseService.client
              .from('orders')
              .select('items')
              .eq('id', _currentOrder.id)
              .single();
          if (orderRes != null && orderRes['items'] != null) {
            final itemsList = orderRes['items'] as List<dynamic>;
            for (final item in itemsList) {
              if (item is Map) {
                final originalId = item['original_id'] as String?;
                final originalType = item['original_type'] as String?;
                if (originalId != null && originalType != null) {
                  if (originalType == 'order') {
                    await SupabaseService.client.from('orders').update({
                      'transaction_id': txnId,
                      'payment_status': 'awaiting_confirmation',
                    }).eq('id', originalId);
                  } else if (originalType == 'quote') {
                    await SupabaseService.client.from('quote_requests').update({
                      'transaction_id': txnId,
                      'status': 'quotation_accepted',
                    }).eq('id', originalId);
                  }
                }
              }
            }
          }
        } catch (e) {
          print('Error propagating transaction ID: $e');
        }
      }

      setState(() {
        _transactionId = txnId;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction ID submitted!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If there's no route to pop back to, navigate to MainNavigation with Orders tab
        if (!Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigation(initialIndex: 3),
            ),
          );
        } else {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: GestureDetector(
            onTap: () {
              final navigator = Navigator.of(context, rootNavigator: true);
              if (!navigator.canPop()) {
                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const MainNavigation(initialIndex: 3),
                  ),
                );
              } else {
                navigator.pop();
              }
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Color(0xFF1E293B)),
            ),
          ),
          title: const Text('Order Details',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B))),
          centerTitle: true,
          actions: [
            GestureDetector(
              onTap: () =>
                  OrderPdfService.generateAndDownloadOrderPdf(_currentOrder),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF4F46E5), size: 20),
              ),
            ),
          ],
        ),
        bottomNavigationBar: null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderInfoCard(),
              const SizedBox(height: 16),
              if (_isDelivered && !_isCheckingReturn) ...[
                _buildReturnInfoBanner(),
                // Only add spacing if the banner produced content
                if (_allItemsNonReturnable || _remainingDays >= 0 || _returns.isNotEmpty)
                  const SizedBox(height: 16),
              ],
              if (_returns.isNotEmpty) ...[
                _buildReturnStatusCard(),
                const SizedBox(height: 16),
              ],
              _buildCustomerDetailsCard(),
              const SizedBox(height: 16),
              _buildSectionHeader('Items', Icons.inventory_2_rounded),
              const SizedBox(height: 12),
              _buildItemsList(),
              const SizedBox(height: 16),
              _buildOrderSummary(),
              if (_paymentReceiptUrl != null) ...[
                const SizedBox(height: 16),
                _buildPaymentReceiptCard(),
              ],
              
              // Transaction ID section — for credit/clearance and bank transfer orders that haven't paid yet
              if ((_currentOrder.paymentSource == 'credit' ||
                      _currentOrder.paymentSource == 'credit_clearance' ||
                      _currentOrder.paymentSource == 'bank_transfer' ||
                      (_currentOrder.paymentMethod?.toLowerCase().contains('credit') ?? false) ||
                      (_currentOrder.paymentMethod?.toLowerCase().contains('bank') ?? false)) &&
                  _currentOrder.paymentStatus?.toLowerCase() != 'paid') ...[
                const SizedBox(height: 16),
                _buildTransactionIdCard(),
              ],

              const SizedBox(height: 24),
              _buildTrackOrderButton(context),
              if (_isDelivered && !_isCheckingReturn) ...[
                const SizedBox(height: 12),
                _buildReturnSection(),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF4F46E5), size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B))),
      ],
    );
  }
  Widget _buildPaymentReceiptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, color: Color(0xFF16A34A), size: 20),
              SizedBox(width: 8),
              Text(
                'Invoice / Bill',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your invoice has been generated for this order.',
            style: TextStyle(fontSize: 13, color: Color(0xFF166534)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openReceiptUrl,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionIdCard() {
    final hasTxnId = _transactionId != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasTxnId ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: hasTxnId ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(hasTxnId ? Icons.check_circle : Icons.account_balance, 
                  color: hasTxnId ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Transaction',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: hasTxnId ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasTxnId) ...[
            Text(
              'Transaction ID: $_transactionId',
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your payment reference has been submitted.',
              style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
            ),
          ] else ...[
            Text(
              (_currentOrder.paymentSource == 'credit' ||
                      _currentOrder.paymentSource == 'credit_clearance' ||
                      (_currentOrder.paymentMethod?.toLowerCase().contains('credit') ?? false))
                  ? 'Please pay your credit balance via Bank Transfer and submit the Transaction ID below.'
                  : 'Please pay via Bank Transfer and submit the Transaction ID / UTR below.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitTransactionId,
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('Submit Transaction ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnInfoBanner() {
    // ----------------------------------------------------------------
    // Case 1: ALL items are explicitly non-returnable (set at quote time)
    // Show a prominent, permanent non-returnable notice.
    // ----------------------------------------------------------------
    if (_allItemsNonReturnable) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Non-Returnable Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFFB91C1B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'The items in this order are non-returnable as agreed during the quotation. '
                    'The return option is not available for this order.',
                    style: TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------------
    // Case 2: Items ARE returnable — show remaining days or expiry
    // ----------------------------------------------------------------
    if (_remainingDays > 0 && _canReturn) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Return period expires within next $_remainingDays day${_remainingDays == 1 ? '' : 's'} for returnable products.',
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_remainingDays == 0 ||
        (_isDelivered && !_canReturn && _returns.isEmpty)) {
      // Check if it's because products are not returnable or if it's expired
      bool allNonReturnable =
          _currentOrder.items.every((item) => !item.isReturnable);
      bool hasReturnable = _currentOrder.items.any((item) => item.isReturnable);

      String msg = '';
      if (allNonReturnable) {
        msg = 'This product return option is not available.';
      } else if (hasReturnable) {
        if (_remainingDays == 0) {
          msg = _expiryMessage.isNotEmpty
              ? _expiryMessage
              : 'Return period has expired for returnable items.';
        } else {
          // If days remain but still can't return, it might be a global policy or empty returnable items
          msg = 'Return option is currently unavailable for this order.';
        }
      } else {
        msg = 'Return policy not applicable for these items.';
      }

      // Show expiry/not returnable message
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_returns.isNotEmpty && !_canReturn) {
      // All items already returned
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFF6B7280).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: Color(0xFF6B7280), size: 20),
            SizedBox(width: 8),
            Text(
              'All items have been returned',
              style: TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildReturnSection() {
    // If all items are non-returnable, show nothing —
    // the non-returnable banner at the top already informs the user.
    if (_allItemsNonReturnable) return const SizedBox.shrink();

    if (_canReturn) {
      return _buildReturnButton();
    } else {
      // Show disabled button with tooltip
      return Tooltip(
        message: _remainingDays == 0
            ? 'Return window expired'
            : 'No items available to return',
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null, // Disabled
            icon: const Icon(Icons.keyboard_return),
            label: const Text('Return Items'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildReturnButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _navigateToReturnRequest,
        icon: const Icon(Icons.keyboard_return),
        label: const Text('Return Items'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0xFFEF4444)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildReturnStatusCard() {
    final latestReturn = _returns.first;
    final color = _getReturnStatusColor(latestReturn.returnStatus);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReturnStatusScreen(returnModel: latestReturn),
          ),
        );
        _loadReturns();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.assignment_return, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Return Request',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(latestReturn.statusText,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.currency_rupee,
                size: 14, color: Color(0xFF64748B)),
            Text(
                ' Est. Refund: ₹${latestReturn.refundAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ]),
          if (latestReturn.returnStatus == 'approved' &&
              !latestReturn.bankDetailsSubmitted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber, size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 6),
                Text('Action needed: Submit bank details',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
              ]),
            ),
          ],
          const SizedBox(height: 6),
          const Text('Tap to view full return timeline →',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
      ),
    );
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

  Widget _buildOrderInfoCard() {
    final statusColor = _getStatusColor(_currentOrder.status);
    return Container(
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
          // Status badge at top
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_rounded,
                    color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Order Info',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const Spacer(),
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
                            color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_getStatusText(_currentOrder.status),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildInfoRow('Order ID',
              '#${_currentOrder.id.replaceAll('-', '').substring(0, 12).toUpperCase()}'),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(height: 1, color: const Color(0xFFF1F5F9))),
          _buildInfoRow(
              'Date',
              DateFormat('dd MMM yyyy, hh:mm a')
                  .format(_currentOrder.createdAt)),
          if (_currentOrder.statusNotes != null &&
              _currentOrder.statusNotes!.isNotEmpty) ...[
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: const Color(0xFFF1F5F9))),
            _buildInfoRow('Note', _currentOrder.statusNotes!, isBold: false),
          ],
          if (_currentOrder.updatedAt != null) ...[
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: const Color(0xFFF1F5F9))),
            _buildInfoRow('Updated',
                DateFormat('dd MMM, hh:mm a').format(_currentOrder.updatedAt!)),
          ],
          if (_currentOrder.items.isNotEmpty) ...[
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: const Color(0xFFF1F5F9))),
            _buildInfoRow(
              'Products',
              _currentOrder.items.map((item) {
                final name = _getItemDisplayName(item);
                final qty =
                    '${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}';
                return '$name × $qty';
              }).join('\n'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerDetailsCard() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Customer & Delivery',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 18),
          if (_currentOrder.customerName != null) ...[
            _buildInfoRow('Name', _currentOrder.customerName!),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: const Color(0xFFF1F5F9))),
          ],
          if (_currentOrder.customerPhone != null) ...[
            _buildInfoRow('Phone', _currentOrder.customerPhone!),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: const Color(0xFFF1F5F9))),
          ],
          _buildInfoRow(
              'Delivery Type',
              _currentOrder.deliveryType == 'pickup_from_shop'
                  ? 'Pickup from Shop'
                  : 'Home Delivery'),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(height: 1, color: const Color(0xFFF1F5F9))),
          if (_currentOrder.deliveryAddress != null) ...[
            _buildInfoRow('Address', _currentOrder.deliveryAddress!),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: const Color(0xFFF1F5F9))),
          ],
          if (_currentOrder.paymentMethod != null) ...[
            _buildInfoRow('Payment', _currentOrder.paymentMethod!),
          ],
          if (_currentOrder.paymentDueDate != null && _currentOrder.paymentStatus?.toLowerCase() != 'paid') ...[
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: const Color(0xFFF1F5F9))),
            Builder(
              builder: (context) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final due = _currentOrder.paymentDueDate!;
                final dueDate = DateTime(due.year, due.month, due.day);
                
                final diff = dueDate.difference(today).inDays;
                String text;
                Color color;
                
                if (diff < 0) {
                  text = 'Overdue by ${-diff} day${-diff == 1 ? '' : 's'} (${DateFormat('dd MMM').format(due)})';
                  color = const Color(0xFFDC2626);
                } else if (diff == 0) {
                  text = 'Due Today';
                  color = const Color(0xFFC2410C);
                } else {
                  text = 'Due in $diff day${diff == 1 ? '' : 's'} (${DateFormat('dd MMM').format(due)})';
                  color = const Color(0xFFEA580C);
                }
                
                return _buildInfoRow('Payment Due', text, color: color, isBold: true);
              }
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _currentOrder.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _currentOrder.items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported,
                                color: Colors.grey, size: 24);
                          },
                        )
                      : const Icon(Icons.inventory_2_outlined,
                          color: Colors.grey, size: 24),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getItemDisplayName(item),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (item.productName.isNotEmpty &&
                        item.qualityOptionName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.qualityOptionName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!item.isReturnable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Text(
                          'Non-returnable',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    Text(
                      '₹${item.unitPrice.toStringAsFixed(2)} x ${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary() {
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calculate_rounded,
                    color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Price Breakdown',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 18),
          _buildSummaryRow('Subtotal', _currentOrder.subtotal),
          const SizedBox(height: 10),
          _buildSummaryRow('GST', _currentOrder.gstAmount),
          const SizedBox(height: 10),
          _buildSummaryRow('Delivery', _currentOrder.deliveryCharge),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(height: 1, color: const Color(0xFFF1F5F9)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '₹${_currentOrder.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          (label == 'Delivery' && amount == 0)
              ? 'Free'
              : '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackOrderButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(order: _currentOrder),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Track Order',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'pending') {
      if (_transactionId != null && _transactionId!.isNotEmpty) {
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

  String _getStatusText(String status) {
    if (status.toLowerCase() == 'pending') {
      if (_transactionId != null && _transactionId!.isNotEmpty) {
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
}
