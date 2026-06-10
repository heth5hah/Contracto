import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';

class PaybackScreen extends StatefulWidget {
  final VoidCallback? onRefresh;

  const PaybackScreen({super.key, this.onRefresh});

  @override
  State<PaybackScreen> createState() => _PaybackScreenState();
}

class _PaybackScreenState extends State<PaybackScreen> {
  final _creditService = BusinessCreditService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  String _selectedFilter = 'This week';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() => _isLoading = true);

      // Get credit usage history
      final usageHistory = await _creditService.getCreditUsageHistory(limit: 50);
      
      // Get billing cycles for payment due
      final billingCycles = await _creditService.getBillingCyclesHistory(limit: 10);
      
      // Get credit payments
      final payments = await _creditService.getCreditPaymentsHistory(limit: 50);
      
      // Combine and format transactions
      final transactions = <Map<String, dynamic>>[];

      // Add outstanding payments (Payment Due)
      for (final cycle in billingCycles) {
        final outstanding = (cycle['outstanding_amount'] ?? 0.0).toDouble();
        if (outstanding > 0 && cycle['status'] == 'open') {
          transactions.add({
            'type': 'payment_due',
            'title': 'Payment Due',
            'subtitle': 'Transaction ID ${cycle['id'].toString().substring(0, 12)}',
            'amount': outstanding,
            'status': 'DUE',
            'date': cycle['due_date'],
            'icon': Icons.refresh,
          });
        }
      }

      // Add credit payments (Cash-in)
      for (final payment in payments) {
        if (payment['payment_status'] == 'completed') {
          transactions.add({
            'type': 'cash_in',
            'title': 'Cash-in',
            'subtitle': payment['payment_method'] == 'bank_transfer'
                ? 'From ABC Bank ATM'
                : 'From Business Credit Payment',
            'amount': (payment['amount'] ?? 0.0).toDouble(),
            'status': 'PAID',
            'date': payment['payment_date'] ?? payment['created_at'],
            'icon': Icons.account_balance_wallet,
            'transaction_id': payment['transaction_id'] ?? payment['id'].toString().substring(0, 12),
          });
        } else if (payment['payment_status'] == 'failed') {
          transactions.add({
            'type': 'transfer',
            'title': 'Transfer to card',
            'subtitle': 'Not enough funds',
            'amount': (payment['amount'] ?? 0.0).toDouble(),
            'status': 'FAILED',
            'date': payment['created_at'],
            'icon': Icons.credit_card,
            'transaction_id': payment['transaction_id'] ?? payment['id'].toString().substring(0, 12),
          });
        }
      }

      // Add credit usage (Transfer to card / Order payment)
      for (final usage in usageHistory) {
        if (usage['transaction_type'] == 'debit') {
          transactions.add({
            'type': 'transfer',
            'title': 'Transfer to card',
            'subtitle': usage['description'] ?? 'Order payment',
            'amount': (usage['amount'] ?? 0.0).toDouble(),
            'status': 'PAID',
            'date': usage['created_at'],
            'icon': Icons.credit_card,
            'transaction_id': usage['id'].toString().substring(0, 12),
          });
        }
      }

      // Sort by date (newest first)
      transactions.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DUE':
        return Colors.orange.shade100;
      case 'PAID':
        return Colors.green.shade100;
      case 'FAILED':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'DUE':
        return Colors.orange.shade700;
      case 'PAID':
        return Colors.green.shade700;
      case 'FAILED':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: Column(
          children: [
            // Filter Tab
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  _buildFilterChip('This week', _selectedFilter == 'This week'),
                  const SizedBox(width: 8),
                  _buildFilterChip('This month', _selectedFilter == 'This month'),
                  const SizedBox(width: 8),
                  _buildFilterChip('All', _selectedFilter == 'All'),
                ],
              ),
            ),
            // Transactions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(_transactions[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = label);
        _loadTransactions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final dateFormat = DateFormat('dd MMM yyyy hh:mm a');
    final date = DateTime.parse(transaction['date']);
    final status = transaction['status'] as String;
    final amount = transaction['amount'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction['icon'] as IconData? ?? Icons.payment,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                if (transaction['subtitle'] != null)
                  Text(
                    transaction['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (transaction['transaction_id'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Transaction ID ${transaction['transaction_id']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  dateFormat.format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Amount and Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_formatAmount(amount)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusTextColor(status),
                  ),
                ),
              ),
            ],
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

