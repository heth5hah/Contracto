import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/credit/presentation/widgets/credit_payment_dialog.dart';
import 'package:contracto_app/features/credit/presentation/screens/payback_screen.dart';
import 'package:contracto_app/features/auth/data/services/user_service.dart';
import 'package:contracto_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:contracto_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:contracto_app/features/orders/data/services/order_service.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/core/services/user_realtime_service.dart';

class BusinessCreditMainScreen extends StatefulWidget {
  final int initialTab;

  const BusinessCreditMainScreen({super.key, this.initialTab = 0});

  @override
  State<BusinessCreditMainScreen> createState() =>
      _BusinessCreditMainScreenState();
}

class _BusinessCreditMainScreenState extends State<BusinessCreditMainScreen>
    with SingleTickerProviderStateMixin {
  final _creditService = BusinessCreditService();
  final _userService = UserService();
  late TabController _tabController;

  bool _isLoading = true;
  double _outstandingAmount = 0.0;
  double _availableCredit = 0.0;
  double _usedCredit = 0.0;
  DateTime? _nextDueDate;

  String? _companyName;
  bool _isIndividual = false;
  int _daysUntilDue = 0;
  List<Map<String, dynamic>> _creditHistory = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _billingCycles = [];

  bool _hasCreditAccount = false;
  String? _kycStatus;
  String? _creditAccountStatus;
  double _creditLimit = 0.0;

  // KYC Application controllers
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _pocNameController = TextEditingController();
  final _pocPhoneController = TextEditingController();
  bool _isSubmittingKYC = false;

  StreamSubscription? _creditSubscription;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadCreditData(forceSync: true);
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _creditSubscription?.cancel();
    _orderSubscription?.cancel();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _pocNameController.dispose();
    _pocPhoneController.dispose();
    super.dispose();
  }

  void _setupRealtimeListener() {
    final realtimeService = UserRealtimeService();
    realtimeService.initialize();

    _creditSubscription = realtimeService.creditAccountUpdatedStream.listen((_) {
      print('🔄 BusinessCreditMainScreen: Credit Account updated in real-time. Reloading...');
      _loadCreditData(forceSync: false);
    });

    _orderSubscription = realtimeService.orderStatusUpdatedStream.listen((_) {
      print('🔄 BusinessCreditMainScreen: Order updated in real-time. Reloading...');
      _loadCreditData(forceSync: false);
    });
  }

  Future<void> _loadCreditData({bool forceSync = false}) async {
    try {
      setState(() => _isLoading = true);

      // Auto-restore credit for any returned orders that were missed only on forceSync
      if (forceSync) {
        try {
          final count = await _creditService.backfillReturnCredits();
          await _creditService
              .hardResetTrueBalances(); // Always lock in true math constraints
          if (count > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Backfilled $count return credits missed. Reset page to view.')),
              );
            });
          }
        } catch (e) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
                context: context,
                builder: (_) =>
                    AlertDialog(content: Text('Backfill Database Error: $e')));
          });
        }
      }

      final creditAccount = await _creditService.getCreditAccount();
      final hasCreditAccount = creditAccount != null;
      final kycStatus = creditAccount?['kyc_status'] as String?;
      final creditAccountStatus = creditAccount?['status'] as String?;
      final creditLimit = creditAccount != null
          ? (creditAccount['credit_limit'] ?? 0.0).toDouble()
          : 0.0;

      final outstandingAmount = await _creditService.getOutstandingAmount();

      final nextDueDate = await _creditService.getNextDueDate();
      final creditHistory =
          await _creditService.getCreditUsageHistory(limit: 200);
      final waitingDays = await _creditService.getWaitingDays();

      final userData = await _userService.getCurrentUserData();
      final companyName = userData?['company_name'] as String?;
      final isIndividual = (userData?['user_type'] as String?) == 'individual';

      if (companyName != null && _companyNameController.text.isEmpty) {
        _companyNameController.text = companyName;
      }
      final userMobile = userData?['mobile'] as String?;
      if (userMobile != null && _companyPhoneController.text.isEmpty) {
        _companyPhoneController.text = userMobile;
      }
      // Prefill address, POC name, and POC phone if they exist in the user profile
      final companyAddress = userData?['company_address'] as String?;
      if (companyAddress != null && _companyAddressController.text.isEmpty) {
        _companyAddressController.text = companyAddress;
      }
      final pocName = userData?['poc_name'] as String?;
      if (pocName != null && _pocNameController.text.isEmpty) {
        _pocNameController.text = pocName;
      }
      final pocPhone = userData?['poc_phone'] as String?;
      if (pocPhone != null && _pocPhoneController.text.isEmpty) {
        _pocPhoneController.text = pocPhone;
      }

      var availableCredit = await _creditService.getAvailableCredit();
      final usedCredit = await _creditService.getUsedCredit();
      final payments = await _creditService.getCreditPaymentsHistory(limit: 20);
      final billingCycles =
          await _creditService.getBillingCyclesHistory(limit: 12);

      // Create unified transactions list
      final allTransactions = <Map<String, dynamic>>[];

      // UI DEDUPLICATION FILTER - Visually clean any stuck DB rows
      final _seenRefundIds = <String>{};
      final filteredCreditHistory = <Map<String, dynamic>>[];
      for (final usage in creditHistory) {
        final desc = (usage['description'] ?? '').toString();
        if (desc.startsWith('Duplicate Correction')) {
          continue; // Hide all correction rows
        }
        if (desc.startsWith('Quote Rejected')) {
          continue; // Hide bogus rejection rows
        }
        if (desc.startsWith('Return refund - Order #')) {
          // Use regex to extract just the 8-char hex order ID
          final match = RegExp(r'Order #([A-F0-9]{8})', caseSensitive: false)
              .firstMatch(desc);
          final orderNum = match?.group(1)?.toUpperCase() ?? '';
          if (orderNum.isNotEmpty && _seenRefundIds.contains(orderNum)) {
            continue; // Hide cloned refunds
          }
          if (orderNum.isNotEmpty) _seenRefundIds.add(orderNum);
        }
        filteredCreditHistory.add(usage);
      }

      // Add usage history
      for (final usage in filteredCreditHistory) {
        allTransactions.add({
          ...usage,
          'source': 'usage',
          'date': usage['created_at'],
        });
      }

      // For individual wallets: ALWAYS fetch refund history from returns table
      // This is the source of truth for individual wallets since credit_usage
      // may be empty if RLS blocked the insert during admin refund processing.
      if (isIndividual) {
        try {
          final user = SupabaseService.instance.currentUser;
          if (user != null) {
            final userData2 = await SupabaseService.client
                .from('users')
                .select('id')
                .eq('email', user.email!)
                .maybeSingle();
            if (userData2 != null) {
              final userReturns = await SupabaseService.client
                  .from('returns')
                  .select('id, order_id, return_status, refund_amount, refund_amount_final, updated_at, refund_processed_at')
                  .eq('user_id', userData2['id'])
                  .inFilter('return_status', ['refund_completed', 'completed'])
                  .order('updated_at', ascending: false);

              double returnsTotal = 0.0;
              for (final ret in userReturns as List) {
                final amt = (ret['refund_amount_final'] as num?)?.toDouble() ??
                    (ret['refund_amount'] as num?)?.toDouble() ??
                    0.0;
                if (amt <= 0) continue;
                returnsTotal += amt;

                final orderId = (ret['order_id'] as String?) ?? '';
                final shortId = orderId.length >= 8
                    ? orderId.replaceAll('-', '').substring(0, 8).toUpperCase()
                    : orderId;

                // Only add to allTransactions if not already in filteredCreditHistory
                // (avoid duplicates when credit_usage was successfully written)
                final alreadyRecorded = _seenRefundIds.contains(shortId);
                if (!alreadyRecorded) {
                  _seenRefundIds.add(shortId);
                  final dateStr = (ret['refund_processed_at'] ?? ret['updated_at']) as String?;
                  allTransactions.add({
                    'transaction_type': 'credit',
                    'amount': amt,
                    'description': 'Return refund - Order #$shortId',
                    'source': 'returns',
                    'date': dateStr,
                    'created_at': dateStr,
                  });
                }
              }

              // If available_credit in DB is still 0 but we have real refunds,
              // compute the true balance from returns (minus any debits from credit_usage)
              if (availableCredit == 0.0 && returnsTotal > 0) {
                // Sum debits from credit_usage (e.g. orders placed with wallet)
                double totalDebits = 0.0;
                for (final usage in creditHistory) {
                  if (usage['transaction_type'] == 'debit') {
                    totalDebits += (usage['amount'] as num?)?.toDouble() ?? 0.0;
                  }
                }
                availableCredit = (returnsTotal - totalDebits).clamp(0.0, double.infinity);
                print('💰 Computed individual wallet balance from returns: returnsTotal=₹$returnsTotal, debits=₹$totalDebits, balance=₹$availableCredit');
              }
            }
          }
        } catch (e) {
          print('Error fetching return history for wallet: $e');
        }
      } else {
        // For business users: Fetch legacy/fallback orders that were bought using 'Business Credit' but aren't in credit_usage
        try {
          final user = SupabaseService.instance.currentUser;
          if (user != null) {
            final userData2 = await SupabaseService.client
                .from('users')
                .select('id')
                .eq('email', user.email!)
                .maybeSingle();
            if (userData2 != null) {
              final userOrders = await SupabaseService.client
                  .from('orders')
                  .select('id, total_amount, created_at')
                  .eq('user_id', userData2['id'])
                  .or('payment_method.eq.Business Credit,payment_source.eq.credit')
                  .not('order_status', 'in', '("cancelled","rejected")');
                  
              final Set<String> existingUsageOrderIds = filteredCreditHistory
                  .map((e) => (e['order_id'] as String?) ?? '')
                  .where((e) => e.isNotEmpty)
                  .toSet();

              for (final order in userOrders as List) {
                final orderId = order['id'] as String;
                if (!existingUsageOrderIds.contains(orderId)) {
                  final amt = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                  final shortId = orderId.length >= 8
                      ? orderId.replaceAll('-', '').substring(0, 8).toUpperCase()
                      : orderId;
                  allTransactions.add({
                    'transaction_type': 'debit',
                    'amount': amt,
                    'description': 'Order payment - #$shortId',
                    'date': order['created_at'],
                    'source': 'orders',
                    'order_id': orderId,
                  });
                }
              }
            }
          }
        } catch (e) {
          print('Error fetching fallback orders: $e');
        }
      }

      // Add payments
      for (final payment in payments) {
        allTransactions.add({
          ...payment,
          'source': 'payment',
          'transaction_type': 'credit',
          'description': payment['notes'] ?? 'Credit Payment',
          'date': payment['payment_date'] ?? payment['created_at'],
        });
      }

      // Sort by date
      allTransactions.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _outstandingAmount = outstandingAmount;
          _availableCredit = availableCredit;
          _usedCredit = usedCredit;
          _creditLimit = creditLimit;
          _nextDueDate = nextDueDate;
          _companyName = companyName;
          _isIndividual = isIndividual;
          _daysUntilDue = waitingDays;
          _creditHistory = allTransactions;
          _allTransactions = allTransactions;
          _billingCycles = billingCycles;
          _hasCreditAccount = hasCreditAccount;
          _kycStatus = kycStatus;
          _creditAccountStatus = creditAccountStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading credit data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePayNow() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreditPaymentDialog(
        outstandingAmount: _outstandingAmount,
      ),
    );

    if (result == true) {
      await _loadCreditData(forceSync: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7C3AED),
          ),
        ),
      );
    }

    if (!_isIndividual) {
      if (_creditLimit == 0.0 && _availableCredit == 0.0) {
        if (!_hasCreditAccount) {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              title: const Text('Apply for Business Credit'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: _buildKYCForm(),
          );
        } else if (_kycStatus == 'pending' || _creditAccountStatus == 'pending') {
          final hasSubmittedKYC = _companyAddressController.text.trim().isNotEmpty &&
              _companyPhoneController.text.trim().isNotEmpty;
              
          if (!hasSubmittedKYC) {
            return Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: AppBar(
                title: const Text('Apply for Business Credit'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              body: _buildKYCForm(),
            );
          }
          
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              title: const Text('Credit Line Pending'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: _buildPendingReviewView(),
          );
        } else if (_creditAccountStatus == 'inactive') {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              title: const Text('Credit Line Suspended'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: _buildSuspendedView(),
          );
        }
      } else {
        // Even if limit > 0, if it is explicitly suspended/inactive, show suspended screen
        if (_creditAccountStatus == 'inactive') {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              title: const Text('Credit Line Suspended'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: _buildSuspendedView(),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light background
      appBar: AppBar(
        title: Text(_isIndividual ? 'Wallet' : 'Business Credit'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF7C3AED),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF7C3AED),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Payback'),
            Tab(text: 'Statements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildHistoryTab(),
          PaybackScreen(
            onRefresh: _loadCreditData,
          ),
          _buildStatementsTab(),
        ],
      ),
    );
  }

  Widget _buildKYCForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card info message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Business Credit Line Request',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please provide the following verification details. Once submitted, our administrator will review and authorize your credit limit.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E40AF),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Company Name
            const Text(
              'Company Name *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companyNameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.business, color: Color(0xFF64748B)),
                hintText: 'Enter Registered Company Name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Company name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Company Contact Number
            const Text(
              'Company Contact Number *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF64748B)),
                hintText: 'Enter Company Phone Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Company contact number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Company Address
            const Text(
              'Company Address *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companyAddressController,
              maxLines: 3,
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40.0),
                  child: Icon(Icons.location_on, color: Color(0xFF64748B)),
                ),
                hintText: 'Enter complete company address',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Company address is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Optional POC Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.person_outline, color: Color(0xFF64748B), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Point of Contact (Optional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),

            // POC Name
            const Text(
              'POC Name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pocNameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person, color: Color(0xFF64748B)),
                hintText: 'Enter contact person name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // POC Phone
            const Text(
              'POC Contact Number',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pocPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.contact_phone, color: Color(0xFF64748B)),
                hintText: 'Enter contact person phone number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmittingKYC ? null : _submitKYCApplication,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isSubmittingKYC
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'SUBMIT APPLICATION',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingReviewView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDDD6FE), width: 2),
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 72,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            const Text(
              'Application Under Review',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            
            // Message
            const Text(
              'We have received your business verification details. Our admin team is currently reviewing your application to allocate a suitable credit limit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),

            // Card summarizing details
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Submitted Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Company Name', _companyNameController.text),
                    _buildSummaryRow('Company Phone', _companyPhoneController.text),
                    _buildSummaryRow('Company Address', _companyAddressController.text),
                    if (_pocNameController.text.isNotEmpty)
                      _buildSummaryRow('Point of Contact', _pocNameController.text),
                    if (_pocPhoneController.text.isNotEmpty)
                      _buildSummaryRow('POC Phone', _pocPhoneController.text),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _loadCreditData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('REFRESH STATUS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                // Show a dialog with helpline info
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Contact Support'),
                    content: const Text('For urgent queries regarding business credit activation, please call or WhatsApp support at +91 9876543210.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('CONTACT SUPPORT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspendedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFEE2E2), width: 2),
              ),
              child: const Icon(
                Icons.block_flipped,
                size: 72,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            const Text(
              'Credit Account Suspended',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            
            // Message
            const Text(
              'Your business credit line is currently inactive. This could be due to unpaid statements or administrative suspension. Please contact support to reactivate your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _loadCreditData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('REFRESH STATUS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Contact Support'),
                    content: const Text('For credit line reinstatement, please contact our support department at support@contractobuild.com or call +91 9876543210.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('CONTACT SUPPORT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitKYCApplication() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmittingKYC = true);
    
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated.');
      }
      
      // 1. Update users table with kyc details
      await SupabaseService.client.from('users').update({
        'company_name': _companyNameController.text.trim(),
        'company_address': _companyAddressController.text.trim(),
        'company_phone': _companyPhoneController.text.trim(),
        'poc_name': _pocNameController.text.trim().isEmpty ? null : _pocNameController.text.trim(),
        'poc_phone': _pocPhoneController.text.trim().isEmpty ? null : _pocPhoneController.text.trim(),
      }).eq('email', currentUser.email!);

      // Get user ID
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', currentUser.email!)
          .maybeSingle();
          
      if (userData == null) {
        throw Exception('User record not found.');
      }
      
      final userId = userData['id'] as String;

      // 2. Check if a credit account already exists. If not, insert one as pending
      final existingAccount = await SupabaseService.client
          .from('business_credit_accounts')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
          
      if (existingAccount == null) {
        await SupabaseService.client.from('business_credit_accounts').insert({
          'user_id': userId,
          'credit_limit': 0.0,
          'available_credit': 0.0,
          'used_credit': 0.0,
          'kyc_status': 'pending',
          'status': 'pending',
        });
      } else {
        await SupabaseService.client.from('business_credit_accounts').update({
          'kyc_status': 'pending',
          'status': 'pending',
        }).eq('user_id', userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification details submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload the data to update status
      await _loadCreditData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingKYC = false);
      }
    }
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadCreditData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outstanding Card
            _buildOutstandingCard(),
            const SizedBox(height: 24),
            // Feature Icons
            _buildFeatureIcons(),
            const SizedBox(height: 24),
            // Credit History
            _buildCreditHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOutstandingCard() {
    return Container(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isIndividual ? 'Wallet Balance' : 'Available Credit',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (!_isIndividual)
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
            const SizedBox(height: 12),
            Text(
              '₹${_formatAmount(_isIndividual ? _availableCredit : _availableCredit)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isIndividual) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCreditDetailSmall('Outstanding', _outstandingAmount),
                  const SizedBox(width: 24),
                  _buildCreditDetailSmall('Used', _usedCredit),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Wait time: $_daysUntilDue days',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (_outstandingAmount > 0)
                    InkWell(
                      onTap: _handlePayNow,
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
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'All Paid ✓',
                            style: TextStyle(
                              color: Color(0xFF10B981),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildFeatureIcon(
          icon: _isIndividual ? Icons.history : Icons.account_balance_wallet,
          label: _isIndividual ? 'History' : 'Payback',
          onTap: () {
            _tabController.animateTo(1);
          },
        ),
        _buildFeatureIcon(
          icon: Icons.receipt_long,
          label: 'Order and Tracking',
          onTap: () {
            // Navigate to orders
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrdersScreen()),
            );
          },
        ),
        _buildFeatureIcon(
          icon: Icons.grid_view,
          label: 'Invite',
          onTap: () {
            // Navigate to invite
            // TODO: Navigate to invite screen
          },
        ),
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
            Text(
              _isIndividual ? 'Transaction History' : 'Credit History',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list, size: 20),
              onPressed: () {
                // TODO: Implement filter
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_creditHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _isIndividual ? 'No transactions yet' : 'No credit history available',
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._creditHistory
              .take(6)
              .map((transaction) => _buildCreditHistoryItem(transaction)),
      ],
    );
  }

  Widget _buildCreditHistoryItem(Map<String, dynamic> transaction) {
    final isDebit = transaction['transaction_type'] == 'debit';
    final amount = (transaction['amount'] ?? 0.0).toDouble();
    final description = transaction['description'] ?? 'Transaction';

    final isQuoteAccepted = description.toLowerCase().contains('quote') &&
        (description.toLowerCase().contains('accepted') ||
            description.toLowerCase().contains('order payment'));
    final isQuoteRejected = description.toLowerCase().contains('quote') &&
        description.toLowerCase().contains('rejected');
    final dateStr = transaction['date'] as String?;
    final createdAt = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () async {
          final orderId = transaction['order_id'];
          if (orderId != null) {
            try {
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED),
                    ),
                  );
                },
              );

              final orderService = OrderService();
              final order = await orderService.getOrderById(orderId);

              if (order != null && context.mounted) {
                // Close loading dialog
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(order: order),
                  ),
                );
              } else if (context.mounted) {
                Navigator.pop(context); // Close loading dialog
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context); // Close loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isQuoteRejected
                      ? Colors.red.shade50
                      : isDebit
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                          : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
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
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDebit ? '-' : '+'}₹${_formatAmount(amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color:
                          isDebit ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                  if (transaction['balance_after'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Bal: ₹${_formatAmount((transaction['balance_after'] ?? 0.0).toDouble())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_allTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded,
                  size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'No transaction history',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your credit usage and payments will appear here',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return RefreshIndicator(
      onRefresh: _loadCreditData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allTransactions.length,
        itemBuilder: (context, index) {
          final transaction = _allTransactions[index];
          final isDebit = transaction['transaction_type'] == 'debit';
          final amount = (transaction['amount'] ?? 0.0).toDouble();
          final dateStr = transaction['date'] as String?;
          final createdAt = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDebit ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDebit
                      ? Icons.shopping_bag_outlined
                      : Icons.account_balance_wallet_outlined,
                  color: isDebit ? Colors.red.shade700 : Colors.green.shade700,
                  size: 24,
                ),
              ),
              title: Text(
                transaction['description'] ??
                    (isDebit ? 'Order Payment' : 'Credit Payment'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  dateFormat.format(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDebit ? '-' : '+'}₹${_formatAmount(amount)}',
                    style: TextStyle(
                      color:
                          isDebit ? Colors.red.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (transaction['balance_after'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        'Bal: ₹${_formatAmount((transaction['balance_after'] ?? 0.0).toDouble())}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatementsTab() {
    if (_billingCycles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'No statements found',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your monthly billing cycles will appear here',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCreditData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _billingCycles.length,
        itemBuilder: (context, index) {
          final cycle = _billingCycles[index];
          final startDate =
              DateTime.tryParse(cycle['cycle_start_date'] ?? '') ??
                  DateTime.now();
          final endDate = DateTime.tryParse(cycle['cycle_end_date'] ?? '') ??
              DateTime.now();
          final dueDate =
              DateTime.tryParse(cycle['due_date'] ?? '') ?? DateTime.now();
          final status = (cycle['status'] ?? 'open').toString().toUpperCase();
          final outstanding = (cycle['outstanding_amount'] ?? 0.0).toDouble();

          final isOverdue =
              status != 'CLOSED' && DateTime.now().isAfter(dueDate);

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isOverdue ? Colors.red.shade200 : Colors.grey.shade200,
                width: isOverdue ? 1.5 : 1.0,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'CLOSED'
                              ? Colors.green.shade50
                              : isOverdue
                                  ? Colors.red.shade50
                                  : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOverdue ? 'OVERDUE' : status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: status == 'CLOSED'
                                ? Colors.green.shade700
                                : isOverdue
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatementDetail('Outstanding',
                          '₹${_formatAmount(outstanding)}', Colors.black),
                      _buildStatementDetail(
                          'Due Date',
                          DateFormat('MMM dd, yyyy').format(dueDate),
                          isOverdue ? Colors.red : Colors.grey.shade700),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (status != 'CLOSED')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handlePayNow(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Pay Statement'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatementDetail(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
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
