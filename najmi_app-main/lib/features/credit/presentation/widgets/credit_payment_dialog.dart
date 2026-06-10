import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/quotations/data/services/email_service.dart';

class CreditPaymentDialog extends StatefulWidget {
  final double outstandingAmount;

  const CreditPaymentDialog({
    super.key,
    required this.outstandingAmount,
  });

  @override
  State<CreditPaymentDialog> createState() => _CreditPaymentDialogState();
}

class _CreditPaymentDialogState extends State<CreditPaymentDialog> {
  bool _isLoading = true;
  bool _isSendingEmail = false;
  List<Map<String, dynamic>> _pendingOrders = [];
  double _totalDue = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return;

      final userData = await SupabaseService.client
          .from('users')
          .select('id, name, email')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) return;
      final userId = userData['id'] as String;

      // Fetch accepted credit quote_requests that haven't been fully paid
      // We only fetch 'quotation_accepted' quote requests. Once they are converted
      // to orders (status 'order_placed'), they are managed in the orders table.
      final creditOrders = await SupabaseService.client
          .from('quote_requests')
          .select('id, created_at, payment_method, total_amount, quotes(total_amount), transaction_id, quote_request_items(products(product_name, name, image_url))')
          .eq('user_id', userId)
          .eq('payment_method', 'credit')
          .eq('status', 'quotation_accepted');

      // Also fetch regular credit/bank-transfer orders that are unpaid
      final regularOrders = await SupabaseService.client
          .from('orders')
          .select('id, created_at, total_amount, payment_source, payment_status, order_status, transaction_id, items')
          .eq('user_id', userId)
          .or('payment_source.eq.credit,payment_method.ilike.%credit%')
          .not('payment_status', 'eq', 'paid')
          .not('order_status', 'in', '("cancelled","returned","rejected")');

      final List<Map<String, dynamic>> allPending = [];
      double total = 0;

      for (final q in creditOrders as List) {
        final amount = ((q['quotes'] as List?)?.isNotEmpty == true
                ? (q['quotes'][0]['total_amount'] as num?)?.toDouble()
                : null) ??
            (q['total_amount'] as num?)?.toDouble() ??
            0.0;
        if (amount > 0) {
          // Skip if admin has already confirmed payment completion or order placement
          final status = q['status'] as String?;
          final payStatus = q['payment_status'] as String?;
          if (status == 'order_placed' ||
              status == 'paid' ||
              payStatus == 'paid' ||
              payStatus == 'completed') {
            continue;
          }

          // If transaction_id is present and is NOT a CREDIT reference, they already submitted payment for it!
          final txnId = q['transaction_id'] as String?;
          final isCreditTxn = txnId != null && txnId.startsWith('CREDIT-');
          if (txnId != null && txnId.isNotEmpty && !isCreditTxn) {
            continue; // Skip, already paid/submitted bank details
          }

          String? imgUrl;
          final List<String> prodNames = [];
          final itemsList = q['quote_request_items'] as List?;
          if (itemsList != null && itemsList.isNotEmpty) {
            for (final item in itemsList) {
              final prod = item['products'];
              if (prod != null && prod is Map) {
                final name = prod['product_name'] as String? ?? prod['name'] as String?;
                if (name != null) prodNames.add(name);
                if (imgUrl == null) {
                  imgUrl = prod['image_url'] as String?;
                }
              }
            }
          }

          allPending.add({
            'type': 'quote',
            'id': q['id'],
            'short_id': (q['id'] as String).replaceAll('-', '').substring(0, 8).toUpperCase(),
            'amount': amount,
            'date': q['created_at'],
            'image_url': imgUrl,
            'product_names': prodNames.join(', '),
          });
          total += amount;
        }
      }

      for (final o in regularOrders as List) {
        final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        if (amount > 0) {
          // If payment_status is 'paid'/'completed' or they already submitted a real transaction ID, skip!
          final txnId = o['transaction_id'] as String?;
          final payStatus = o['payment_status'] as String?;
          final isCreditTxn = txnId == null || txnId.isEmpty || txnId.startsWith('CREDIT-');
          if (payStatus == 'paid' ||
              payStatus == 'completed' ||
              (!isCreditTxn)) {
            continue; // Skip, already paid or submitted a real transaction ID
          }

           String? imgUrl;
          final List<String> prodNames = [];
          final itemsList = o['items'] as List?;
          if (itemsList != null && itemsList.isNotEmpty) {
            for (final item in itemsList) {
              if (item is Map) {
                final name = item['product_name'] as String? ?? item['name'] as String?;
                if (name != null) prodNames.add(name);
                if (imgUrl == null) {
                  imgUrl = item['image_url'] as String? ?? item['product_image'] as String?;
                }
              }
            }
          }

          allPending.add({
            'type': 'order',
            'id': o['id'],
            'short_id': (o['id'] as String).replaceAll('-', '').substring(0, 8).toUpperCase(),
            'amount': amount,
            'date': o['created_at'],
            'image_url': imgUrl,
            'product_names': prodNames.join(', '),
          });
          total += amount;
        }
      }

      if (mounted) {
        setState(() {
          _pendingOrders = allPending;
          _totalDue = total > 0 ? total : widget.outstandingAmount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading pending orders: $e');
      if (mounted) {
        setState(() {
          _totalDue = widget.outstandingAmount;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendPaymentEmail() async {
    setState(() => _isSendingEmail = true);
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final userData = await SupabaseService.client
          .from('users')
          .select('id, name, email, mobile, company_name')
          .eq('email', user.email!)
          .maybeSingle();

      final customerName = userData?['company_name'] ?? userData?['name'] ?? 'Business User';
      final customerEmail = userData?['email'] ?? user.email ?? '';

      // Build items list from pending orders (for the email)
      final items = _pendingOrders.map((o) => {
        'product_name': '${o['type'] == 'quote' ? 'Quote' : 'Order'} #${o['short_id']}',
        'quantity': 1,
        'total_price': o['amount'],
      }).toList();

      if (items.isEmpty) {
        items.add({
          'product_name': 'Outstanding Credit Balance',
          'quantity': 1,
          'total_price': _totalDue,
        });
      }

      // Build combined DB order items (with original_id and original_type
      // so the Orders screen can propagate the transaction ID back)
      final orderItems = _pendingOrders.map((o) => {
        'product_id': '00000000-0000-0000-0000-000000000000',
        'product_name': '${o['type'] == 'quote' ? 'Quote' : 'Order'} #${o['short_id']}',
        'quantity': 1,
        'unit_price': o['amount'],
        'total_price': o['amount'],
        'is_returnable': false,
        'original_id': o['id'],
        'original_type': o['type'],
        'image_url': o['image_url'],
      }).toList();

      if (orderItems.isEmpty) {
        orderItems.add({
          'product_id': '00000000-0000-0000-0000-000000000000',
          'product_name': 'Outstanding Credit Balance',
          'quantity': 1,
          'unit_price': _totalDue,
          'total_price': _totalDue,
          'is_returnable': false,
        });
      }

      // Create a combined clearance order — user enters TXN ID on this order
      // in the Orders section; admin then confirms it
      final orderData = {
        'user_id': userData?['id'],
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_phone': userData?['mobile'] ?? '',
        'delivery_address': 'Combined Credit Payment Clearance',
        'delivery_type': 'pickup_from_shop',
        'payment_method': 'Bank Transfer',
        'order_status': 'pending',              // must be a valid check-constraint value
        'payment_status': 'awaiting_confirmation',
        'payment_source': 'credit_clearance',
        'total_amount': _totalDue,
        'subtotal': _totalDue,
        'gst_amount': 0.0,
        'delivery_charge': 0.0,
        'invoice_required': false,
        'items': orderItems,
        'created_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client.from('orders').insert([orderData]);

      // Send bank details email
      final emailSent = await EmailService().sendBankDetailsEmail(
        customerEmail: customerEmail,
        customerName: customerName,
        quotationId:
            'OUTSTANDING-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        items: items,
        totalAmount: _totalDue,
        date: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emailSent
                ? '✅ Bank details sent to $customerEmail.\n'
                  'Go to Orders → open the clearance order → submit your Transaction ID.'
                : '⚠️ Could not send email — please contact support.'),
            backgroundColor: emailSent ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(dynamic dateStr) {
    try {
      if (dateStr == null) return '';
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Outstanding Payments',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total Due: ₹${_totalDue.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ── Pending Orders List ──────────────────────────────────
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                            color: Color(0xFF7C3AED)),
                      ),
                    )
                  : _pendingOrders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF10B981), size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'No pending orders found.',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Outstanding amount: ₹${_totalDue.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _pendingOrders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final o = _pendingOrders[i];
                            final isQuote = o['type'] == 'quote';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isQuote
                                          ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                                          : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: (o['image_url'] != null && (o['image_url'] as String).isNotEmpty)
                                        ? Image.network(
                                            o['image_url'] as String,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(
                                              isQuote ? Icons.description_outlined : Icons.shopping_bag_outlined,
                                              size: 16,
                                              color: isQuote ? const Color(0xFF7C3AED) : const Color(0xFF3B82F6),
                                            ),
                                          )
                                        : Icon(
                                            isQuote ? Icons.description_outlined : Icons.shopping_bag_outlined,
                                            size: 16,
                                            color: isQuote ? const Color(0xFF7C3AED) : const Color(0xFF3B82F6),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${isQuote ? 'Quote' : 'Order'} #${o['short_id']}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B)),
                                        ),
                                        if (o['product_names'] != null && (o['product_names'] as String).isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            o['product_names'] as String,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if (o['date'] != null)
                                          Text(
                                            _formatDate(o['date']),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF94A3B8)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${(o['amount'] as double).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // ── Bottom: info + send button ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF3B82F6), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bank transfer details will be sent to your email. '
                            'After paying, go to Orders and submit your UTR / Transaction ID there.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingEmail ? null : _sendPaymentEmail,
                      icon: _isSendingEmail
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSendingEmail
                            ? 'Sending...'
                            : 'Send Bank Transfer Details',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
}
