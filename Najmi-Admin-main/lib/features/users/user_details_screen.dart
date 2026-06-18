import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_model.dart';
import 'users_provider.dart';
import '../orders/order_model.dart';
import '../quotations/quotation_model.dart'; // Ensure correct import
import 'package:najmi_admin/main.dart';

class UserDetailsScreen extends ConsumerStatefulWidget {
  final AdminUser user;

  const UserDetailsScreen({super.key, required this.user});

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _orders = [];
  List<Quotation> _quotations = [];
  bool _isLoadingOrders = true;
  bool _isLoadingQuotes = true;

  // Live credit state (refreshed independently)
  double? _creditLimit;
  double? _availableCredit;
  double? _usedCredit;
  String? _kycStatus;
  String? _creditAccountStatus;
  bool _isLoadingCredit = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
    _fetchQuotations();
    // Seed from already-loaded user model
    _creditLimit = widget.user.creditLimit;
    _availableCredit = widget.user.availableCredit;
    _usedCredit = widget.user.usedCredit;
    _kycStatus = widget.user.kycStatus;
    _creditAccountStatus = widget.user.creditAccountStatus;
    // Refresh live credit data if this is a business user
    if (widget.user.isBusiness) _refreshCreditData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshCreditData() async {
    if (!mounted) return;
    setState(() => _isLoadingCredit = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('business_credit_accounts')
          .select('credit_limit, available_credit, used_credit, kyc_status, status')
          .eq('user_id', widget.user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _creditLimit = (res?['credit_limit'] as num?)?.toDouble();
          _availableCredit = (res?['available_credit'] as num?)?.toDouble();
          _usedCredit = (res?['used_credit'] as num?)?.toDouble();
          _kycStatus = res?['kyc_status']?.toString();
          _creditAccountStatus = res?['status']?.toString();
          _isLoadingCredit = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCredit = false);
    }
  }

  Future<void> _showCreditDialog() async {
    final creditLimitController = TextEditingController(
      text: _creditLimit?.toStringAsFixed(0) ?? '0',
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _creditLimit == null ? 'Activate Business Credit' : 'Edit Business Credit',
              style: const TextStyle(fontSize: 16),
            )),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.companyName ?? widget.user.email,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (_creditLimit != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _creditRow('Credit Limit', '₹${NumberFormat('#,##,###').format(_creditLimit)}', Colors.black87),
                      const SizedBox(height: 6),
                      _creditRow('Available', '₹${NumberFormat('#,##,###').format(_availableCredit ?? 0)}', Colors.green[700]!),
                      const SizedBox(height: 6),
                      _creditRow('Used', '₹${NumberFormat('#,##,###').format(_usedCredit ?? 0)}', Colors.orange[700]!),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: creditLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Credit Limit (₹)',
                  hintText: 'e.g. 50000',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _creditLimit == null
                    ? 'This will activate business credit for this user. They will be able to pay using credit at checkout.'
                    : 'Update the credit limit. Available credit will be recalculated.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
            icon: Icon(_creditLimit == null ? Icons.check_circle : Icons.save),
            label: Text(_creditLimit == null ? 'Activate Credit' : 'Update Limit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newLimit = double.tryParse(creditLimitController.text.replaceAll(',', ''));
              if (newLimit == null || newLimit <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid positive amount')),
                );
                return;
              }
              try {
                final supabase = ref.read(supabaseProvider);
                final existing = await supabase
                    .from('business_credit_accounts')
                    .select('id')
                    .eq('user_id', widget.user.id)
                    .maybeSingle();
                if (existing == null) {
                  await supabase.from('business_credit_accounts').insert({
                    'user_id': widget.user.id,
                    'credit_limit': newLimit,
                    'available_credit': newLimit,
                    'used_credit': 0,
                    'kyc_status': 'approved',
                    'status': 'active',
                  });
                } else {
                  final used = _usedCredit ?? 0;
                  await supabase
                      .from('business_credit_accounts')
                      .update({
                        'credit_limit': newLimit,
                        'available_credit': newLimit - used,
                        'kyc_status': 'approved',
                        'status': 'active',
                      })
                      .eq('user_id', widget.user.id);
                }
                ref.invalidate(usersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                await _refreshCreditData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_creditLimit == null
                          ? 'Business credit activated successfully!'
                          : 'Credit limit updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _creditRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchOrders() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', widget.user.id)
          .order('created_at', ascending: false);
      
      final data = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _orders = data.map((json) {
              // Basic handling to ensure it parses correctly even if some fields are missing
              return Order.fromJson(json);
          }).toList();
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      print('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _fetchQuotations() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('quote_requests')
          .select('''
            *,
            quote_request_items(*,products(*,brands(*)),brands!brand_id(*)),
            quotes(*,quote_items(*,brands!brand_id(*))),
            users:user_id(*)
          ''')
          .eq('user_id', widget.user.id)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _quotations = data.map((json) => Quotation.fromJson(json)).toList();
          _isLoadingQuotes = false;
        });
      }
    } catch (e) {
      print('Error fetching quotations: $e');
       if (mounted) {
        setState(() {
          _isLoadingQuotes = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.user.name ?? 'User Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8B5CF6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B5CF6),
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Quotations'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildUserProfileHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersTab(),
                _buildQuotationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.1),
                  child: Text(
                    widget.user.name?[0].toUpperCase() ?? 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            widget.user.email,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      if (widget.user.phone != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              widget.user.phone!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.user.status == 'blocked'
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.user.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.user.status == 'blocked' ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Spent',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(widget.user.totalSpent),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Business Credit Card (only for business accounts)
          if (widget.user.isBusiness) ...[
            Divider(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _creditLimit != null
                          ? const Color(0xFF8B5CF6).withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 20,
                      color: _creditLimit != null ? const Color(0xFF8B5CF6) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isLoadingCredit
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _creditLimit != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Business Credit — ${_creditAccountStatus == 'active' ? 'Active' : 'Inactive'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: _creditAccountStatus == 'active' ? const Color(0xFF8B5CF6) : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Limit: ₹${NumberFormat('#,##,###').format(_creditLimit)}  •  Avail: ₹${NumberFormat('#,##,###').format(_availableCredit ?? 0)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Business Credit — Not Activated',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Activate to let this user pay via credit at checkout',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                  ),
                  const SizedBox(width: 8),
                  if (_creditLimit != null) 
                    ElevatedButton.icon(
                      onPressed: () async {
                        final newStatus = _creditAccountStatus == 'active' ? 'inactive' : 'active';
                        try {
                          setState(() => _isLoadingCredit = true);
                          final supabase = ref.read(supabaseProvider);
                          await supabase
                              .from('business_credit_accounts')
                              .update({'status': newStatus})
                              .eq('user_id', widget.user.id);
                          
                          await _refreshCreditData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Credit ${newStatus == 'active' ? 'Activated' : 'Suspended'} successfully!'),
                                backgroundColor: newStatus == 'active' ? Colors.green : Colors.orange,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                             setState(() => _isLoadingCredit = false);
                             ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        _creditAccountStatus == 'active' ? Icons.block : Icons.check_circle_outline, 
                        size: 16
                      ),
                      label: Text(_creditAccountStatus == 'active' ? 'Suspend' : 'Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _creditAccountStatus == 'active' ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showCreditDialog,
                    icon: Icon(_creditLimit != null ? Icons.edit : Icons.add, size: 16),
                    label: Text(_creditLimit != null ? 'Limit' : 'Activate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _creditLimit != null
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Business Credit KYC Details
          if (widget.user.isBusiness) ...[
            Divider(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 8),
                      Text(
                        'Business Registration & KYC Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.user.companyName != null && widget.user.companyName!.isNotEmpty)
                    _buildInfoRow('Company Name', widget.user.companyName!),
                  if (widget.user.gstNumber != null && widget.user.gstNumber!.isNotEmpty)
                    _buildInfoRow('GST Number', widget.user.gstNumber!),
                  _buildInfoRow('GST Registered', widget.user.isGstRegistered ? 'Yes' : 'No'),
                  if (widget.user.panNumber != null && widget.user.panNumber!.isNotEmpty)
                    _buildInfoRow('PAN Number', widget.user.panNumber!),
                  if (widget.user.companyAddress != null && widget.user.companyAddress!.isNotEmpty)
                    _buildInfoRow('Company Address', widget.user.companyAddress!),
                  if (widget.user.companyPhone != null && widget.user.companyPhone!.isNotEmpty)
                    _buildInfoRow('Company Phone', widget.user.companyPhone!),
                  if (widget.user.pocName != null && widget.user.pocName!.isNotEmpty)
                    _buildInfoRow('Point of Contact', widget.user.pocName!),
                  if (widget.user.pocPhone != null && widget.user.pocPhone!.isNotEmpty)
                    _buildInfoRow('POC Phone', widget.user.pocPhone!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_orders.isEmpty) {
      return const Center(child: Text('No orders found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade200)
          ),
          child: ListTile(
            title: Text(
              'Order #${order.id.substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)),
                const SizedBox(height: 4),
                Text('${order.items?.length ?? 0} items'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(order.totalAmount ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                _buildStatusChip(order.status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuotationsTab() {
     if (_isLoadingQuotes) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_quotations.isEmpty) {
      return const Center(child: Text('No quotations found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _quotations.length,
      itemBuilder: (context, index) {
        final quote = _quotations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
           elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade200)
          ),
          child: ListTile(
            title: Text(
              'Quote #${quote.id.substring(0, 8)}',
               style: const TextStyle(fontWeight: FontWeight.bold),
            ),
             subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM yyyy, hh:mm a').format(quote.createdAt)),
                if (quote.items.isNotEmpty)
                    Text('Item: ${quote.items.first.productName}${quote.items.length > 1 ? ' +${quote.items.length - 1} more' : ''}'),
              ],
            ),
             trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 if (quote.totalAmount > 0)
                    Text(
                      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(quote.totalAmount),
                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                const SizedBox(height: 4),
                _buildStatusChip(quote.status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
      case 'delivered':
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
      case 'processing':
        color = Colors.orange;
        break;
      case 'cancelled':
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
