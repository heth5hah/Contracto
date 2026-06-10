import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:najmi_admin/main.dart';

// Provides a list of active billing cycles joined with user info
final businessBillingProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  // Fetch business credit accounts
  List accounts = [];
  try {
    final accountsRes = await supabase.from('business_credit_accounts').select('''
      id, user_id, credit_limit, used_credit, available_credit, status,
      is_frozen, freeze_reason, frozen_at, unfrozen_at
    ''');
    accounts = accountsRes as List;
  } catch (e) {
    print('CRITICAL: Failed to fetch business_credit_accounts: $e');
    throw Exception('business_credit_accounts is failing: $e');
  }

  // Extract user IDs to fetch them separately
  final userIds = accounts.map((a) => a['user_id']).whereType<String>().toSet().toList();
  
  List usersData = [];
  if (userIds.isNotEmpty) {
    try {
      final usersRes = await supabase
          .from('users')
          .select('id, name, email, mobile, company_name, user_type')
          .inFilter('id', userIds);
      usersData = usersRes as List;
    } catch (e) {
      print('Warning: Failed to fetch users independently: $e');
    }
  }

  // Fetch open billing cycles
  List cycles = [];
  try {
    final cyclesRes = await supabase
        .from('billing_cycles')
        .select('*')
        .eq('status', 'open');
    cycles = cyclesRes as List;
  } catch (e) {
    print('CRITICAL: Failed to fetch billing_cycles: $e');
  }

  // Fetch credit-paid orders for each business user (exclude returned)
  List allOrders = [];
  try {
    final allOrdersRes = await supabase
        .from('orders')
        .select('id, user_id, order_status, total_amount, created_at, customer_name, payment_due_date, payment_due_days, payment_method, transaction_id, payment_source, payment_status')
        .neq('order_status', 'returned')
        .neq('order_status', 'cancelled')
        .order('created_at', ascending: false);
    allOrders = allOrdersRes as List;
  } catch (e) {
    print('CRITICAL: Failed to fetch orders: $e');
  }

  // Fetch credit_usage to link orders to credit accounts
  List usageList = [];
  try {
    final usageRes = await supabase
        .from('credit_usage')
        .select('credit_account_id, order_id, amount, transaction_type, created_at')
        .eq('transaction_type', 'debit')
        .order('created_at', ascending: false);
    usageList = usageRes as List;
  } catch (e) {
    print('CRITICAL: Failed to fetch credit_usage: $e');
  }
  
  // Combine data
  List<Map<String, dynamic>> combined = [];
  for (final account in accounts) {
    final userId = account['user_id'];
    // Find matching user from our separate query
    final user = usersData.firstWhere((u) => u['id'] == userId, orElse: () => <String, dynamic>{}) as Map;
    
    // STRICTLY skip non-business users so they don't pollute the dashboard
    final userType = user['user_type']?.toString() ?? '';
    final hasCompany = (user['company_name']?.toString() ?? '').trim().isNotEmpty;
    if (userType != 'company' && !hasCompany) continue;
    
    final accountId = account['id'];
    final matchingCycles = cycles.where((c) => c['credit_account_id'] == accountId).toList();
    
    // Sort by due_date descending to get the latest
    matchingCycles.sort((a, b) => (b['due_date'] ?? '').compareTo(a['due_date'] ?? ''));
    
    final currentCycle = matchingCycles.isNotEmpty ? matchingCycles.first : null;

    // Get credit-paid orders for this account
    final accountUsage = usageList.where((u) => u['credit_account_id'] == accountId).toList();
    final creditOrderIds = accountUsage.map((u) => u['order_id']).whereType<String>().toSet();
    final creditOrders = allOrders.where((o) => 
      o['user_id'] == userId || creditOrderIds.contains(o['id'])
    ).toList();
    
    combined.add({
      'account_id': accountId,
      'user_id': userId,
      'company_name': user['company_name'] ?? user['name'] ?? user['email'],
      'email': user['email'],
      'phone': user['mobile'],  // Map mobile to phone for display
      'user_type': user['user_type'] ?? 'individual',
      'used_credit': account['used_credit'],
      'available_credit': account['available_credit'],
      'credit_limit': account['credit_limit'],
      'account_status': account['status'],
      'is_frozen': account['is_frozen'] ?? false,
      'freeze_reason': account['freeze_reason'],
      'frozen_at': account['frozen_at'],
      'unfrozen_at': account['unfrozen_at'],
      'cycle_id': currentCycle?['id'],
      'due_date': currentCycle?['due_date'],
      'outstanding_amount': currentCycle?['outstanding_amount'] ?? 0,
      'credit_orders': creditOrders,
      'credit_order_ids': creditOrderIds, // Set<String> of IDs that had credit_usage debit
      'order_count': creditOrders.length,
    });
  }
  
  // Sort by overdue first, then by outstanding amount
  combined.sort((a, b) {
    final aDue = a['due_date'];
    final bDue = b['due_date'];
    final now = DateTime.now().toIso8601String().split('T')[0];
    
    final aOverdue = aDue != null && aDue.compareTo(now) < 0;
    final bOverdue = bDue != null && bDue.compareTo(now) < 0;
    
    if (aOverdue && !bOverdue) return -1;
    if (!aOverdue && bOverdue) return 1;
    
    return (b['outstanding_amount'] as num).compareTo(a['outstanding_amount'] as num);
  });
  
  return combined;
});

// Update Due Date Provider
// Saves BOTH payment_due_date (computed) and payment_due_days (the raw days granted)
// so we always know exactly how many days were given for each order.
// Also sends a payment notification with bank details — same as the bank transfer quote flow.
final updateDueDateProvider = FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final orderId = params['order_id'] as String?;
    final newDueDate = params['due_date'] as String?; // ISO date string YYYY-MM-DD
    final userId = params['user_id'] as String?;
    final customDays = params['custom_days'] as int? ?? 0;

    if (orderId != null && newDueDate != null) {
      // Save both the computed due date AND the number of days granted
      await supabase.from('orders').update({
        'payment_due_date': newDueDate,
        'payment_due_days': customDays,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
    }

    // Notify the user with bank payment details (same flow as payment_details_sent for quotations)
    if (userId != null && orderId != null) {
      try {
        final shortId = orderId.replaceAll('-', '').substring(0, 5).toUpperCase();

        // Fetch company bank details to include in the notification
        String bankDetailsText = '';
        try {
          final bankRows = await supabase
              .from('company_bank_details')
              .select('account_holder_name, bank_name, account_number, ifsc_code, upi_id')
              .limit(1);
          if (bankRows != null && (bankRows as List).isNotEmpty) {
            final bank = bankRows.first as Map<String, dynamic>;
            bankDetailsText = '\n\nBank Details:\n'
                'Account Holder: ${bank['account_holder_name'] ?? '-'}\n'
                'Bank: ${bank['bank_name'] ?? '-'}\n'
                'Account No: ${bank['account_number'] ?? '-'}\n'
                'IFSC: ${bank['ifsc_code'] ?? '-'}'
                '${(bank['upi_id'] as String?)?.isNotEmpty == true ? '\nUPI: ${bank['upi_id']}' : ''}';
          }
        } catch (e) {
          print('Could not fetch bank details (non-critical): $e');
        }

        await supabase.from('notifications').insert({
          'user_id': userId,
          'title': 'Payment Due — Order #$shortId',
          'message': 'Your credit order #$shortId has a payment window of $customDays days. '
              'Please transfer the amount via bank transfer by $newDueDate.$bankDetailsText\n\n'
              'After payment, submit your transaction ID in the app under My Orders → Order #$shortId.',
          'type': 'billing',
          'source': 'admin',
          'target': 'user',
          'reference_id': orderId,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Notification insert failed (non-critical): $e');
      }
    }

    ref.invalidate(businessBillingProvider);
    return true;
  } catch (e) {
    print('Error updating due date: $e');
    return false;
  }
});

class BusinessBillingScreen extends ConsumerWidget {
  const BusinessBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(businessBillingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (billingList) {
          if (billingList.isEmpty) {
            return const Center(child: Text('No business credit accounts found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              const Text(
                'Business Billing & Credit Control',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set custom payment windows. Accounts are automatically frozen if the due date passes without payment. Returned orders are excluded.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    ...billingList.map((item) => _BillingRow(item: item)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: Colors.grey[50],
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Business', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Credit Usage', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Orders', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Pending Bill', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _BillingRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  const _BillingRow({required this.item});

  @override
  ConsumerState<_BillingRow> createState() => _BillingRowState();
}

class _BillingRowState extends ConsumerState<_BillingRow> {
  bool _expanded = false;

  Future<void> _unfreezeAccount(String accountId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfreeze Account'),
        content: const Text('Are you sure you want to unfreeze this account? Make sure the user has cleared their overdue balances.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unfreeze'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('business_credit_accounts').update({
        'is_frozen': false,
        'status': 'active',
        'freeze_reason': null,
        'frozen_at': null,
        'unfrozen_at': DateTime.now().toIso8601String(),
      }).eq('id', accountId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account unfrozen successfully'), backgroundColor: Colors.green),
        );
      }
      ref.invalidate(businessBillingProvider);
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
    final item = widget.item;
    final outstanding = (item['used_credit'] as num?)?.toDouble() ?? 0.0;
    final orderCount = item['order_count'] as int? ?? 0;
    final creditOrders = item['credit_orders'] as List? ?? [];
    
    bool isOverdue = false;
    DateTime? earliestDueDate;
    
    final unfrozenAtStr = item['unfrozen_at'] as String?;
    final unfrozenAt = unfrozenAtStr != null ? DateTime.tryParse(unfrozenAtStr) : null;

    // Check all unpaid orders for due dates
    for (var order in creditOrders) {
      if (order['payment_due_date'] != null) {
        final due = DateTime.parse(order['payment_due_date']);
        if (earliestDueDate == null || due.isBefore(earliestDueDate)) {
          earliestDueDate = due;
        }
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (due.isBefore(today)) {
          final isBypassed = unfrozenAt != null &&
              (due.isBefore(unfrozenAt) ||
               (order['created_at'] != null && DateTime.parse(order['created_at'].toString()).isBefore(unfrozenAt)));
          if (!isBypassed) {
            isOverdue = true;
          }
        }
      }
    }
    
    final dueDateStr = earliestDueDate != null ? earliestDueDate.toIso8601String() : null;
    
    String statusText = 'Good Standing';
    Color statusColor = Colors.green;
    final isFrozen = item['is_frozen'] == true;
    
    if (isFrozen) {
      statusText = 'FROZEN';
      statusColor = Colors.red;
    } else if (isOverdue) {
      statusText = 'OVERDUE (FROZEN)';
      statusColor = Colors.red;
      
      // Auto-freeze: update account status if overdue
      _autoFreezeIfNeeded(item);
    }

    if (!isFrozen && !isOverdue) {
      if (item['account_status'] == 'inactive') {
        statusText = 'FROZEN';
        statusColor = Colors.red;
      } else if (item['account_status'] == 'pending') {
        statusText = 'PENDING ACTIVATION';
        statusColor = Colors.orange;
      } else if (outstanding == 0 && (item['used_credit'] as num) > 0) {
        statusText = 'Pending Sync';
        statusColor = Colors.orange;
      }
    }

    final currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
            color: _expanded ? const Color(0xFFF0F9FF) : null,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['company_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(item['email'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (item['phone'] != null)
                      Text(item['phone'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${currencyFormat.format(item['used_credit'])} / ₹${currencyFormat.format(item['credit_limit'])}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text('Available: ₹${currencyFormat.format(item['available_credit'])}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: creditOrders.isNotEmpty ? () => setState(() => _expanded = !_expanded) : null,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: orderCount > 0 ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$orderCount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: orderCount > 0 ? const Color(0xFF3B82F6) : Colors.grey,
                          ),
                        ),
                      ),
                      if (creditOrders.isNotEmpty)
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16, color: const Color(0xFF3B82F6),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '₹${currencyFormat.format(outstanding)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: outstanding > 0 ? Colors.orange[800] : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  dueDateStr != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(dueDateStr)) : 'Not Set',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : (dueDateStr != null ? Colors.black87 : Colors.grey),
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isFrozen || isOverdue || item['account_status'] == 'inactive')
                      IconButton(
                        icon: const Icon(Icons.lock_open, color: Colors.green),
                        tooltip: 'Unfreeze Account',
                        onPressed: () => _unfreezeAccount(item['account_id']),
                      ),
                    if (creditOrders.isNotEmpty)
                      IconButton(
                        icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.blue),
                        tooltip: 'View Orders',
                        onPressed: () => setState(() => _expanded = !_expanded),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Expandable orders list
        if (_expanded && creditOrders.isNotEmpty)
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Orders by ${item['company_name']} (excluding returned)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
                  ),
                ),
                ...creditOrders.take(20).map((order) {
                  final status = order['order_status'] ?? 'unknown';
                  final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
                  final date = order['created_at'] != null 
                      ? DateFormat('dd MMM yyyy').format(DateTime.parse(order['created_at']))
                      : '-';
                  final orderDueDateStr = order['payment_due_date'] as String?;
                  final orderDueDate = orderDueDateStr != null 
                      ? DateFormat('dd MMM').format(DateTime.parse(orderDueDateStr))
                      : 'No Due Date';
                  final shortId = (order['id'] as String).replaceAll('-', '').substring(0, 5).toUpperCase();

                  // Determine if this order was paid via credit line or bank transfer.
                  // Three signals — any one is sufficient:
                  //   1. payment_source == 'credit'
                  //   2. payment_method contains 'credit'
                  //   3. order ID appears in credit_usage debit entries
                  final paymentSource = (order['payment_source'] ?? '') as String;
                  final paymentMethod = (order['payment_method'] ?? '') as String;
                  final creditOrderIds = (item['credit_order_ids'] as Set<String>?) ?? <String>{};
                  final isCreditOrder = paymentSource == 'credit' ||
                      paymentMethod.toLowerCase().contains('credit') ||
                      creditOrderIds.contains(order['id'] as String? ?? '');

                  Color orderStatusColor;
                  switch (status) {
                    case 'delivered': orderStatusColor = Colors.green; break;
                    case 'pending': orderStatusColor = Colors.orange; break;
                    case 'confirmed': orderStatusColor = Colors.blue; break;
                    case 'completed': orderStatusColor = const Color(0xFF059669); break;
                    default: orderStatusColor = Colors.grey;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCreditOrder
                            ? Colors.blue.withOpacity(0.15)
                            : Colors.green.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('#$shortId', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        // Order status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: orderStatusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(status, style: TextStyle(fontSize: 10, color: orderStatusColor, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        // Payment type badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCreditOrder
                                ? const Color(0xFFDDD6FE) // purple-ish for credit
                                : const Color(0xFFD1FAE5), // green for bank transfer
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCreditOrder ? 'Credit' : 'Bank Transfer',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isCreditOrder
                                  ? const Color(0xFF5B21B6)
                                  : const Color(0xFF065F46),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${NumberFormat('#,##,##0.00', 'en_IN').format(amount)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            if (isCreditOrder)
                              Row(
                                children: [
                                  Text(
                                    'Due: $orderDueDate',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: orderDueDateStr != null ? Colors.red[700] : Colors.grey,
                                    ),
                                  ),
                                  if (order['payment_due_days'] != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${order['payment_due_days']}d)',
                                      style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                                    ),
                                  ],
                                ],
                              )
                            else
                              Text(
                                'Direct payment',
                                style: TextStyle(fontSize: 10, color: Colors.green[700]),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Credit orders: set payment window days
                        // Bank Transfer orders: allow admin to reclassify as credit if misclassified
                        if (isCreditOrder)
                          IconButton(
                            icon: const Icon(Icons.edit_calendar, color: Colors.blue, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Set payment window (days) for this credit order',
                            onPressed: () => _showEditDaysDialog(context, ref, item, order),
                          )
                        else
                          IconButton(
                            icon: Icon(Icons.swap_horiz_rounded,
                                color: Colors.grey[400], size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Mark as Credit Line order (if misclassified)',
                            onPressed: () => _markOrderAsCredit(context, ref, order),
                          ),
                      ],
                    ),
                  );
                }),
                if (creditOrders.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('...and ${creditOrders.length - 20} more orders',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _autoFreezeIfNeeded(Map<String, dynamic> item) async {
    if (item['account_status'] == 'active') {
      try {
        final supabase = ref.read(supabaseProvider);
        await supabase
            .from('business_credit_accounts')
            .update({'status': 'inactive', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', item['account_id']);
        print('❄️ Auto-froze account for ${item['company_name']} (overdue)');
      } catch (e) {
        print('Error auto-freezing: $e');
      }
    }
  }

  void _showEditDaysDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> item, Map<String, dynamic> order) {
    // Pre-fill: use saved payment_due_days if available, else derive from due date vs today
    int defaultDays = 15;
    if (order['payment_due_days'] != null) {
      // Use the exact days that were previously saved
      defaultDays = (order['payment_due_days'] as num).toInt();
    } else if (order['payment_due_date'] != null) {
      try {
        final dueDate = DateTime.parse(order['payment_due_date']);
        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final diff = DateTime(dueDate.year, dueDate.month, dueDate.day).difference(today).inDays;
        if (diff > 0) defaultDays = diff;
      } catch (_) {}
    }

    final controller = TextEditingController(text: defaultDays.toString());
    final shortOrderId = (order['id'] as String).replaceAll('-', '').substring(0, 5).toUpperCase();
    final amount = (order['total_amount'] as num?)?.toStringAsFixed(0) ?? '0';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment Window — Order #$shortOrderId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context for admin
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['company_name'] ?? 'Business',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text('Amount: ₹$amount', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'How many days should this business have to pay for this order?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            // Quick select chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [5, 7, 10, 15, 30].map((days) => ActionChip(
                label: Text('$days days'),
                onPressed: () => controller.text = '$days',
                backgroundColor: const Color(0xFFEFF6FF),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of days from today',
                border: OutlineInputBorder(),
                suffixText: 'days',
                helperText: 'Due date = today + this many days',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final days = int.tryParse(controller.text.trim()) ?? 15;
              if (days <= 0) return; // ignore nonsense
              final newDueDate = DateTime.now()
                  .add(Duration(days: days))
                  .toIso8601String()
                  .split('T')[0];

              Navigator.pop(context);

              final success = await ref.read(updateDueDateProvider({
                'order_id': order['id'],
                'due_date': newDueDate,       // computed date string
                'user_id': item['user_id'],
                'custom_days': days,          // raw days — saved to payment_due_days
              }).future);

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment window set: $days days (due $newDueDate)'),
                    backgroundColor: Colors.green[700],
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }

              ref.invalidate(businessBillingProvider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Allows admin to correct a misclassified Bank Transfer order → Credit Line.
  /// Updates payment_source in the orders table so the edit button appears.
  Future<void> _markOrderAsCredit(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
  ) async {
    final shortId = (order['id'] as String).replaceAll('-', '').substring(0, 5).toUpperCase();
    final amount = (order['total_amount'] as num?)?.toStringAsFixed(0) ?? '0';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.swap_horiz_rounded, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text('Reclassify Order #$shortId'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Color(0xFFEA580C), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order #$shortId (₹$amount) is showing as "Bank Transfer". '
                    'Mark it as Credit Line if it was paid using credit.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFC2410C)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will update the order\'s payment type so you can set the payment window days.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Yes, Mark as Credit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('orders').update({
        'payment_source': 'credit',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', order['id'] as String);

      ref.invalidate(businessBillingProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$shortId marked as Credit Line. You can now set the payment window.'),
            backgroundColor: Colors.blue[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
