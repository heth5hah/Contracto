import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/credit/presentation/widgets/credit_payment_dialog.dart';

class BusinessCreditScreen extends StatefulWidget {
  const BusinessCreditScreen({super.key});

  @override
  State<BusinessCreditScreen> createState() => _BusinessCreditScreenState();
}

class _BusinessCreditScreenState extends State<BusinessCreditScreen> {
  final _creditService = BusinessCreditService();
  bool _isLoading = true;
  double _creditLimit = 0.0;
  double _availableCredit = 0.0;
  double _usedCredit = 0.0;
  DateTime? _nextDueDate;
  double _outstandingAmount = 0.0;
  List<Map<String, dynamic>> _usageHistory = [];
  List<Map<String, dynamic>> _billingCycles = [];
  int _selectedTab = 0; // 0: Overview, 1: History, 2: Statements

  @override
  void initState() {
    super.initState();
    _loadCreditData();
  }

  Future<void> _loadCreditData() async {
    try {
      setState(() => _isLoading = true);

      final creditLimit = await _creditService.getCreditLimit();
      final availableCredit = await _creditService.getAvailableCredit();
      final usedCredit = await _creditService.getUsedCredit();
      final nextDueDate = await _creditService.getNextDueDate();
      final outstandingAmount = await _creditService.getOutstandingAmount();
      final usageHistory = await _creditService.getCreditUsageHistory();
      final billingCycles = await _creditService.getBillingCyclesHistory();

      if (mounted) {
        setState(() {
          _creditLimit = creditLimit;
          _availableCredit = availableCredit;
          _usedCredit = usedCredit;
          _nextDueDate = nextDueDate;
          _outstandingAmount = outstandingAmount;
          _usageHistory = usageHistory;
          _billingCycles = billingCycles;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading credit data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading credit data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePayment() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreditPaymentDialog(
        outstandingAmount: _outstandingAmount,
      ),
    );

    if (result == true) {
      // Reload data after payment
      await _loadCreditData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Credit'),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCreditData,
              child: Column(
                children: [
                  // Tabs
                  Container(
                    color: Colors.white,
                    child: Row(
                      children: [
                        _buildTab(0, 'Overview'),
                        _buildTab(1, 'History'),
                        _buildTab(2, 'Statements'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: _selectedTab == 0
                        ? _buildOverviewTab()
                        : _selectedTab == 1
                            ? _buildHistoryTab()
                            : _buildStatementsTab(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF1E40AF) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF1E40AF) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final usagePercentage = _creditLimit > 0 ? (_usedCredit / _creditLimit) : 0.0;
    final dateFormat = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Credit Summary Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Credit Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSummaryRow('Total Credit Limit', '₹${_formatAmount(_creditLimit)}'),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Available Credit', '₹${_formatAmount(_availableCredit)}'),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Used Credit', '₹${_formatAmount(_usedCredit)}'),
                  const SizedBox(height: 20),
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Credit Utilization',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            '${(usagePercentage * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: usagePercentage,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Outstanding Amount Card
          if (_outstandingAmount > 0)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Outstanding Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹${_formatAmount(_outstandingAmount)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    if (_nextDueDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Due Date: ${dateFormat.format(_nextDueDate!)}',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handlePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_outstandingAmount > 0) const SizedBox(height: 16),

          // Quick Info
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Credit Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoItem(
                    Icons.info_outline,
                    'Credit Limit',
                    '₹${_formatAmount(_creditLimit)}',
                  ),
                  const Divider(),
                  _buildInfoItem(
                    Icons.check_circle_outline,
                    'Available Credit',
                    '₹${_formatAmount(_availableCredit)}',
                  ),
                  const Divider(),
                  _buildInfoItem(
                    Icons.shopping_cart_outlined,
                    'Used Credit',
                    '₹${_formatAmount(_usedCredit)}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_usageHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No transaction history',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _usageHistory.length,
      itemBuilder: (context, index) {
        final transaction = _usageHistory[index];
        final isDebit = transaction['transaction_type'] == 'debit';
        final amount = (transaction['amount'] ?? 0.0).toDouble();
        final createdAt = DateTime.parse(transaction['created_at']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDebit ? Colors.red.shade100 : Colors.green.shade100,
              child: Icon(
                isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isDebit ? Colors.red : Colors.green,
              ),
            ),
            title: Text(
              transaction['description'] ?? 'Transaction',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(dateFormat.format(createdAt)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isDebit ? '-' : '+'}₹${_formatAmount(amount)}',
                  style: TextStyle(
                    color: isDebit ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Balance: ₹${_formatAmount((transaction['balance_after'] ?? 0.0).toDouble())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatementsTab() {
    if (_billingCycles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No billing statements available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _billingCycles.length,
      itemBuilder: (context, index) {
        final cycle = _billingCycles[index];
        final startDate = DateTime.parse(cycle['cycle_start_date']);
        final endDate = DateTime.parse(cycle['cycle_end_date']);
        final dueDate = DateTime.parse(cycle['due_date']);
        final outstanding = (cycle['outstanding_amount'] ?? 0.0).toDouble();
        final status = cycle['status'] ?? 'open';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Icon(
              status == 'closed' ? Icons.check_circle : Icons.pending,
              color: status == 'closed' ? Colors.green : Colors.orange,
            ),
            title: Text('Billing Cycle ${index + 1}'),
            subtitle: Text(
              '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatementRow('Total Charges', '₹${_formatAmount((cycle['total_charges'] ?? 0.0).toDouble())}'),
                    _buildStatementRow('Total Payments', '₹${_formatAmount((cycle['total_payments'] ?? 0.0).toDouble())}'),
                    _buildStatementRow('Outstanding', '₹${_formatAmount(outstanding)}'),
                    _buildStatementRow('Due Date', dateFormat.format(dueDate)),
                    _buildStatementRow('Status', status.toUpperCase()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildStatementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
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
}

