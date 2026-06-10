import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/credit/presentation/screens/business_credit_main_screen.dart';

class BusinessCreditWidget extends StatefulWidget {
  const BusinessCreditWidget({super.key});

  @override
  State<BusinessCreditWidget> createState() => _BusinessCreditWidgetState();
}

class _BusinessCreditWidgetState extends State<BusinessCreditWidget> {
  final _creditService = BusinessCreditService();
  bool _isLoading = true;
  double _creditLimit = 0.0;
  double _availableCredit = 0.0;
  double _usedCredit = 0.0;
  DateTime? _nextDueDate;
  double _outstandingAmount = 0.0;
  bool _isEligible = false;

  @override
  void initState() {
    super.initState();
    _loadCreditData();
  }

  Future<void> _loadCreditData() async {
    try {
      setState(() => _isLoading = true);

      // Check if credit account exists (even if KYC not approved)
      final creditAccount = await _creditService.getCreditAccount();
      if (creditAccount == null) {
        // No credit account exists - don't show widget
        setState(() {
          _isEligible = false;
          _isLoading = false;
        });
        return;
      }

      // Check KYC status
      final isEligible = await _creditService.isEligibleForCredit();
      
      // Load credit data regardless of KYC status (to show pending status)
      final creditLimit = await _creditService.getCreditLimit();
      final availableCredit = await _creditService.getAvailableCredit();
      final usedCredit = await _creditService.getUsedCredit();
      final nextDueDate = await _creditService.getNextDueDate();
      final outstandingAmount = await _creditService.getOutstandingAmount();

      if (mounted) {
        setState(() {
          _creditLimit = creditLimit;
          _availableCredit = availableCredit;
          _usedCredit = usedCredit;
          _nextDueDate = nextDueDate;
          _outstandingAmount = outstandingAmount;
          _isEligible = isEligible; // Show widget but may show KYC pending message
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading credit data: $e');
      if (mounted) {
        setState(() {
          _isEligible = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return _buildLoadingCard();
    }

    // Don't render if no credit account exists (not a business account)
    if (_creditLimit == 0.0 && _availableCredit == 0.0) {
      return const SizedBox.shrink();
    }

    return _buildCreditCard();
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildCreditCard() {
    final usagePercentage = _creditLimit > 0 ? (_usedCredit / _creditLimit) : 0.0;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
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
          child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BusinessCreditMainScreen(),
                    ),
                  );
                },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Business Credit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BusinessCreditMainScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KYC Pending Warning (if not eligible)
                  if (!_isEligible) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'KYC verification pending. Complete KYC to use Business Credit.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Credit Limit
                  _buildInfoRow(
                    'Total Credit Limit',
                    '₹${_formatAmount(_creditLimit)}',
                    Icons.credit_card,
                  ),
                  const SizedBox(height: 12),

                  // Available Credit
                  _buildInfoRow(
                    'Available Credit',
                    '₹${_formatAmount(_availableCredit)}',
                    Icons.check_circle_outline,
                    valueColor: Colors.green.shade100,
                  ),
                  const SizedBox(height: 12),

                  // Used Credit
                  _buildInfoRow(
                    'Used Credit',
                    '₹${_formatAmount(_usedCredit)}',
                    Icons.shopping_cart_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Usage Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Credit Utilization',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${(usagePercentage * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),

                  if (_outstandingAmount > 0) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white30),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Outstanding Amount',
                      '₹${_formatAmount(_outstandingAmount)}',
                      Icons.payment,
                      valueColor: Colors.orange.shade100,
                    ),
                    if (_nextDueDate != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Next Due Date',
                        dateFormat.format(_nextDueDate!),
                        Icons.calendar_today,
                        valueColor: Colors.orange.shade100,
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isEligible
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const BusinessCreditMainScreen(),
                                  ),
                                );
                              }
                            : null, // Disable if KYC not approved
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E40AF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _isEligible ? 'Pay Due' : 'KYC Pending',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
}

