import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/credit/presentation/screens/business_credit_main_screen.dart';
import 'package:contracto_app/features/auth/data/services/user_service.dart';
import 'package:contracto_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:contracto_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:contracto_app/features/orders/data/services/order_service.dart';
import 'package:contracto_app/features/credit/presentation/widgets/credit_payment_dialog.dart';
import 'package:contracto_app/features/credit/data/services/credit_notification_service.dart';
import 'package:contracto_app/core/services/user_realtime_service.dart';

class BusinessCreditWidgetV2 extends StatefulWidget {
  const BusinessCreditWidgetV2({super.key});

  @override
  State<BusinessCreditWidgetV2> createState() => _BusinessCreditWidgetV2State();
}

class _BusinessCreditWidgetV2State extends State<BusinessCreditWidgetV2> {
  final _creditService = BusinessCreditService();
  final _userService = UserService();
  bool _isLoading = true;
  double _outstandingAmount = 0.0;
  double _creditLimit = 0.0;
  double _availableCredit = 0.0;
  double _usedCredit = 0.0;
  List<Map<String, dynamic>> _creditHistory = [];
  String? _companyName;
  String _accountStatus = 'active'; // 'active', 'pending', 'inactive'
  int _daysUntilDue = 0;
  bool _isIndividual = false;

  StreamSubscription? _creditSubscription;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _loadCreditData(forceSync: true);
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _creditSubscription?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    final realtimeService = UserRealtimeService();
    realtimeService.initialize();

    _creditSubscription = realtimeService.creditAccountUpdatedStream.listen((_) {
      print('🔄 BusinessCreditWidgetV2: Credit Account updated in real-time. Reloading...');
      _loadCreditData(forceSync: false);
    });

    _orderSubscription = realtimeService.orderStatusUpdatedStream.listen((_) {
      print('🔄 BusinessCreditWidgetV2: Order updated in real-time. Reloading...');
      _loadCreditData(forceSync: false);
    });
  }

  Future<void> _loadCreditData({bool forceSync = false}) async {
    try {
      setState(() => _isLoading = true);

      print('BusinessCreditWidget: Loading credit data (forceSync: $forceSync)...');

      // Get company name and user type first
      final userData = await _userService.getCurrentUserData();
      final companyName = userData?['company_name'] as String?;
      final userType = (userData?['user_type'] as String?) ?? 'individual';
      final isIndividual = userType == 'individual';

      print('BusinessCreditWidget: Company name = $companyName, User type = $userType');

      // Check if credit account exists
      final creditAccount = await _creditService.getCreditAccount();
      print('BusinessCreditWidget: Credit account = ${creditAccount != null}');

      if (creditAccount == null) {
        if (isIndividual) {
          print('BusinessCreditWidget: No credit account found for individual - widget will not show');
          setState(() {
            _isLoading = false;
            _isIndividual = true;
          });
          return;
        } else {
          print('BusinessCreditWidget: No credit account found for business - showing Apply card');
          setState(() {
            _isLoading = false;
            _isIndividual = false;
            _accountStatus = 'not_applied';
            _companyName = companyName;
          });
          return;
        }
      }

      // Track account status
      final companyAddress = userData?['company_address'] as String?;
      final companyPhone = userData?['company_phone'] as String?;
      final hasSubmittedKYC = (companyAddress != null && companyAddress.trim().isNotEmpty) &&
          (companyPhone != null && companyPhone.trim().isNotEmpty);

      final creditLimit = await _creditService.getCreditLimit();
      var accountStatus = (creditAccount['status'] as String?) ?? 'active';
      if (accountStatus == 'pending' && !hasSubmittedKYC && creditLimit == 0.0) {
        accountStatus = 'not_applied';
      }

      print('BusinessCreditWidget: Credit account found: ${creditAccount['id']}, Status: $accountStatus');

      // Ensure structural integrity of balances and backfills only on forceSync
      if (forceSync) {
        try {
          await _creditService.backfillReturnCredits();
          await _creditService.hardResetTrueBalances();
        } catch (e) {
          print('BusinessCreditWidget true balance calculation warning: $e');
        }
      }

      // Get outstanding amount, credit limit, and due date
      final outstandingAmount = await _creditService.getOutstandingAmount();
      final nextDueDate = await _creditService.getNextDueDate();
      final waitingDays = await _creditService.getWaitingDays();

      // Schedule notifications if we have a due date
      if (nextDueDate != null) {
        await CreditNotificationService().scheduleCreditReminders(
          dueDate: nextDueDate,
          paymentDueDays: waitingDays > 0 ? waitingDays : 15,
          amount: outstandingAmount,
        );
      }

      print('BusinessCreditWidget: Credit limit = $creditLimit, Outstanding = $outstandingAmount');

      // Correctly display the outstanding balance as 0.0 when no debt exists
      final displayAmount = outstandingAmount;

      // Get available and used credit
      final availableCredit = await _creditService.getAvailableCredit();
      final usedCredit = await _creditService.getUsedCredit();

      // Load credit history: fetch a large batch so Duplicate Correction rows
      // (which may be the most recent) don't eat up the limit before real items.
      final rawHistory = await _creditService.getCreditUsageHistory(limit: 100);
      final seenRefundIds = <String>{};
      final filteredHistory = <Map<String, dynamic>>[];
      for (final tx in rawHistory) {
        if (filteredHistory.length >= 5) break; // Show max 5 on widget
        final desc = (tx['description'] ?? '').toString();
        if (desc.startsWith('Duplicate Correction')) continue;
        if (desc.startsWith('Quote Rejected')) continue;
        if (desc.startsWith('Return refund - Order #')) {
          final match = RegExp(r'Order #([A-F0-9]{8})', caseSensitive: false)
              .firstMatch(desc);
          final orderNum = match?.group(1)?.toUpperCase() ?? '';
          if (orderNum.isNotEmpty && seenRefundIds.contains(orderNum)) continue;
          if (orderNum.isNotEmpty) seenRefundIds.add(orderNum);
        }
        filteredHistory.add(tx);
      }

      print(
          'BusinessCreditWidget: Available = $availableCredit, Used = $usedCredit');

      if (mounted) {
        setState(() {
          _outstandingAmount = displayAmount;
          _creditLimit = creditLimit;
          _availableCredit = availableCredit;
          _usedCredit = usedCredit;
          _companyName = companyName;
          _accountStatus = accountStatus;
          _isIndividual = isIndividual;
          _daysUntilDue = waitingDays;
          _creditHistory = filteredHistory;
          _isLoading = false;
        });
        print(
            'BusinessCreditWidget: State updated - Status: $accountStatus, Credit limit: $creditLimit, Available: $availableCredit, Used: $usedCredit');
      }
    } catch (e) {
      print('BusinessCreditWidget: Error loading credit data: $e');
      print('BusinessCreditWidget: Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isIndividual && _creditLimit == 0.0 && _availableCredit == 0.0) {
      if (_accountStatus == 'not_applied') {
        return _buildApplyForCreditCard();
      }
    }

    // Don't show if no credit account or (credit limit is 0 AND available credit is 0 AND not pending)
    // Individual users have credit_limit = 0, but they can have available_credit from refunds
    if (_creditLimit == 0.0 && _availableCredit == 0.0 && _accountStatus != 'pending') {
      return const SizedBox.shrink();
    }

    // Show "Awaiting Approval" card for pending accounts
    if (_accountStatus == 'pending' && _creditLimit == 0.0 && _availableCredit == 0.0) {
      return _buildPendingApprovalCard();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Outstanding Card
          _buildOutstandingCard(),
          const SizedBox(height: 16),
          // Feature Icons
          _buildFeatureIcons(),
          const SizedBox(height: 16),
          // Credit History Section
          _buildCreditHistorySection(),
        ],
      ),
    );
  }

  Widget _buildOutstandingCard() {
    // ── Individual wallet card (refund balance only, no credit line, no PAY NOW) ──
    if (_isIndividual) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BusinessCreditMainScreen(),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Credit Balance Available',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_formatAmount(_availableCredit)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Available from return refunds · Tap to view history',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Business credit card (with PAY NOW) ──────────────────────────────────
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BusinessCreditMainScreen(),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 180),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Available Credit and Company Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Credit',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _companyName ?? 'Company',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Large Amount
              Text(
                '₹${_formatAmount(_availableCredit)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Credit Limit, Outstanding and Used row
              Row(
                children: [
                  Flexible(
                      child: _buildCreditDetailSmall(
                          'Credit Limit', _creditLimit)),
                  const SizedBox(width: 8),
                  Flexible(
                      child: _buildCreditDetailSmall(
                          'Outstanding', _outstandingAmount)),
                  const SizedBox(width: 8),
                  Flexible(child: _buildCreditDetailSmall('Used', _usedCredit)),
                ],
              ),

              const SizedBox(height: 16),
              // Bottom Row: Wait time and Pay Now button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Dynamic Wait Time with Color Coding
                  Builder(builder: (context) {
                    Color statusColor;
                    String statusText;

                    if (_daysUntilDue > 5) {
                      statusColor = Colors.white70; // Normal/Safe
                      statusText = '✅ Pay within $_daysUntilDue days';
                    } else if (_daysUntilDue > 1) {
                      statusColor = const Color(0xFFFDBA74); // Orange/Warning
                      statusText = '⏳ Pay within $_daysUntilDue days';
                    } else {
                      statusColor = const Color(0xFFFCA5A5); // Red/Critical
                      statusText = '🚨 Pay within $_daysUntilDue days';
                    }

                    // If overdue (days <= 0), change message
                    if (_daysUntilDue <= 0) {
                      statusColor = const Color(0xFFEF4444);
                      statusText = '🚨 OVERDUE';
                    }

                    return Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }),
                  if (_outstandingAmount > 0)
                    GestureDetector(
                      onTap: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => CreditPaymentDialog(
                            outstandingAmount: _outstandingAmount,
                          ),
                        );
                        if (result == true) {
                          // Cancel reminders and refresh credit data after successful payment
                          await CreditNotificationService().cancelReminders();
                          _loadCreditData(forceSync: true);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PAY NOW',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white70, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'All Paid ✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyForCreditCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BusinessCreditMainScreen(),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.business_center_outlined, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Get Business Credit Line',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Apply for a custom credit line for your business. Fast approvals, interest-free days, and simple repayments.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'APPLY NOW',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApprovalCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Credit Line Awaiting Approval',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _companyName != null
                    ? 'Your business credit for $_companyName is under review by the admin. You will be notified once approved.'
                    : 'Your business credit account is under review. You will be notified once approved by the admin.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending_outlined, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'PENDING APPROVAL',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildFeatureIcon(
          icon: Icons.account_balance_wallet,
          label: 'Payback',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const BusinessCreditMainScreen(initialTab: 1),
              ),
            );
          },
        ),
        _buildFeatureIcon(
          icon: Icons.receipt_long,
          label: 'Order and Tracking',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OrdersScreen(),
              ),
            );
          },
        ),
        // "Invite" feature removed from this widget (e.g. Quotations section)
      ],
    );
  }

  Widget _buildFeatureIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF22C55E),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: const Color(0xFF22C55E),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF166534),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Credit History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const BusinessCreditMainScreen(initialTab: 1),
                  ),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Show recent credit transactions from pre-loaded state
        if (_creditHistory.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No credit history yet',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _creditHistory.length,
            itemBuilder: (context, index) {
              return _buildCreditHistoryItem(_creditHistory[index]);
            },
          ),
      ],
    );
  }

  Widget _buildCreditHistoryItem(Map<String, dynamic> transaction) {
    final isDebit = transaction['transaction_type'] == 'debit';
    final amount = (transaction['amount'] ?? 0.0).toDouble();
    final description = transaction['description'] ??
        (isDebit ? 'Order Payment' : 'Credit Payment');
    final dateStr = transaction['created_at'] as String?;
    final createdAt = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    // Determine if it's quote related
    final isQuoteAccepted = description.toLowerCase().contains('quote') &&
        (description.toLowerCase().contains('accepted') ||
            description.toLowerCase().contains('order payment'));
    final isQuoteRejected = description.toLowerCase().contains('quote') &&
        description.toLowerCase().contains('rejected');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final orderId = transaction['order_id'];
          if (orderId != null) {
            try {
              final orderService = OrderService();
              final order = await orderService.getOrderById(orderId);

              if (order != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(order: order),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          }
        },
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isQuoteRejected
                    ? Colors.red.shade50
                    : isDebit
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                        : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isQuoteRejected
                    ? Icons.close_rounded
                    : isDebit
                        ? Icons.shopping_bag_outlined
                        : Icons.account_balance_wallet_outlined,
                color: isQuoteRejected
                    ? Colors.red.shade700
                    : isDebit
                        ? const Color(0xFF7C3AED)
                        : Colors.green.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isQuoteAccepted
                        ? 'Quote Accepted'
                        : isQuoteRejected
                            ? 'Quote Rejected'
                            : description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isDebit ? '-' : '+'}₹${_formatAmount(amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color:
                        isDebit ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
                if (transaction['balance_after'] != null)
                  Text(
                    'Bal: ₹${_formatAmount((transaction['balance_after'] ?? 0.0).toDouble())}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildCreditDetailSmall(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '₹${_formatAmount(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
