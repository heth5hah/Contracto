import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'coupon_provider.dart';
import '../users/users_provider.dart';
import '../users/user_model.dart';
import '../products/products_provider.dart';
import '../products/product_model.dart';

class CouponManagementScreen extends ConsumerWidget {
  const CouponManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('Building CouponManagementScreen');
    final couponsAsync = ref.watch(couponsProvider);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                const Text(
                  'Coupon Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    debugPrint('DEBUG: Create Coupon button clicked');
                    _showCouponDialog(context, ref, null);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Coupon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: couponsAsync.when(
                  data: (coupons) {
                    print('=== COUPONS LOADED: ${coupons.length} ===');
                    if (coupons.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_offer_outlined, size: 64, color: Color(0xFF64748B)),
                            const SizedBox(height: 16),
                            const Text(
                              'No coupons yet. Create your first coupon!',
                              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showCouponDialog(context, ref, null),
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Coupon'),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Min Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Valid Until', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Usage', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          rows: coupons.map((coupon) {
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  coupon.code,
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                )),
                                DataCell(Text(
                                  coupon.discountType == 'percentage' ? 'Percentage' : 'Fixed',
                                  style: const TextStyle(color: Color(0xFF334155)),
                                )),
                                DataCell(Text(
                                  coupon.discountType == 'percentage'
                                      ? '${coupon.discountValue}%'
                                      : '₹${coupon.discountValue}',
                                  style: const TextStyle(color: Color(0xFF334155)),
                                )),
                                DataCell(Text(
                                  '₹${coupon.minOrderValue.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Color(0xFF334155)),
                                )),
                                DataCell(Text(
                                  coupon.validTo != null
                                      ? dateFormat.format(coupon.validTo!)
                                      : 'No expiry',
                                  style: const TextStyle(color: Color(0xFF334155)),
                                )),
                                DataCell(Text(
                                  coupon.usageLimit != null
                                      ? '${coupon.timesUsed}/${coupon.usageLimit}'
                                      : '${coupon.timesUsed}/∞',
                                  style: const TextStyle(color: Color(0xFF334155)),
                                )),
                                DataCell(_StatusBadge(isActive: coupon.isActive)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _showCouponDialog(context, ref, coupon),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          coupon.isActive ? Icons.toggle_on : Icons.toggle_off,
                                          size: 18,
                                        ),
                                        onPressed: () => ref
                                            .read(couponManagementProvider)
                                            .toggleCouponStatus(coupon.id, !coupon.isActive),
                                        tooltip: coupon.isActive ? 'Deactivate' : 'Activate',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () => _deleteCoupon(context, ref, coupon.id),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () {
                    debugPrint('Coupons Loading...');
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading coupons...'),
                        ],
                      ),
                    );
                  },
                  error: (error, stack) {
                    debugPrint('Coupons ERROR: $error');
                    debugPrint('Stack trace: $stack');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading coupons',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              debugPrint('Retrying coupons fetch');
                              ref.refresh(couponsProvider);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCouponDialog(BuildContext context, WidgetRef ref, Coupon? coupon) {
    showDialog(
      context: context,
      builder: (context) => _CouponDialog(coupon: coupon),
    );
  }

  void _deleteCoupon(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coupon'),
        content: const Text('Are you sure you want to delete this coupon?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(couponManagementProvider).deleteCoupon(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CouponDialog extends ConsumerStatefulWidget {
  final Coupon? coupon;

  const _CouponDialog({this.coupon});

  @override
  ConsumerState<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends ConsumerState<_CouponDialog> {
  late TextEditingController codeController;
  late TextEditingController descriptionController;
  late TextEditingController discountValueController;
  late TextEditingController minAmountController;
  late TextEditingController maxDiscountController;
  late TextEditingController usageLimitController;
  late TextEditingController applicableUsersController;
  late TextEditingController applicableProductsController;
  
  String discountType = 'percentage';
  DateTime? validTo;

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController(text: widget.coupon?.code ?? '');
    descriptionController = TextEditingController(text: widget.coupon?.description ?? '');
    discountValueController = TextEditingController(
      text: widget.coupon?.discountValue.toString() ?? '',
    );
    minAmountController = TextEditingController(
      text: widget.coupon?.minOrderValue.toString() ?? '0',
    );
    maxDiscountController = TextEditingController(
      text: widget.coupon?.maxDiscount?.toString() ?? '',
    );
    usageLimitController = TextEditingController(
      text: widget.coupon?.usageLimit?.toString() ?? '',
    );
    applicableUsersController = TextEditingController(
      text: widget.coupon?.applicableUsers.join(', ') ?? '',
    );
    applicableProductsController = TextEditingController(
      text: widget.coupon?.applicableProducts.join(', ') ?? '',
    );
    discountType = widget.coupon?.discountType ?? 'percentage';
    validTo = widget.coupon?.validTo;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.coupon == null ? 'Create Coupon' : 'Edit Coupon'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Coupon Code',
                  hintText: 'e.g., SAVE20',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: discountType,
                decoration: const InputDecoration(labelText: 'Discount Type'),
                items: const [
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                ],
                onChanged: (value) => setState(() => discountType = value!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountValueController,
                decoration: InputDecoration(
                  labelText: discountType == 'percentage' ? 'Discount %' : 'Discount Amount (₹)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minAmountController,
                decoration: const InputDecoration(labelText: 'Minimum Order Amount (₹)'),
                keyboardType: TextInputType.number,
              ),
              if (discountType == 'percentage') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: maxDiscountController,
                  decoration: const InputDecoration(
                    labelText: 'Max Discount Cap (₹)',
                    hintText: 'Optional',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: usageLimitController,
                decoration: const InputDecoration(
                  labelText: 'Usage Limit',
                  hintText: 'Leave empty for unlimited',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Valid Until'),
                subtitle: Text(validTo != null
                    ? DateFormat('yyyy-MM-dd').format(validTo!)
                    : 'No expiry'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: validTo ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => validTo = date);
                },
              ),
              const Divider(height: 32),
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text('Advanced Restrictions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              InkWell(
                onTap: () => _selectUsers(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Specific User Emails',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    applicableUsersController.text.isEmpty
                        ? 'All Users (Tap to select)'
                        : applicableUsersController.text,
                    style: TextStyle(
                      color: applicableUsersController.text.isEmpty
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectProducts(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Specific Product IDs',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    applicableProductsController.text.isEmpty
                        ? 'All Products (Tap to select)'
                        : applicableProductsController.text,
                    style: TextStyle(
                      color: applicableProductsController.text.isEmpty
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ),
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
          onPressed: _saveCoupon,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveCoupon() async {
    try {
      final coupon = Coupon(
        id: widget.coupon?.id ?? '',
        code: codeController.text,
        description: descriptionController.text.isEmpty ? null : descriptionController.text,
        discountType: discountType,
        discountValue: double.parse(discountValueController.text),
        minOrderValue: double.parse(minAmountController.text),
        maxDiscount: maxDiscountController.text.isEmpty
            ? null
            : double.parse(maxDiscountController.text),
        validFrom: widget.coupon?.validFrom ?? DateTime.now().toUtc(),
        validTo: validTo,
        usageLimit: usageLimitController.text.isEmpty
            ? null
            : int.parse(usageLimitController.text),
        timesUsed: widget.coupon?.timesUsed ?? 0,
        createdAt: widget.coupon?.createdAt ?? DateTime.now().toUtc(),
        applicableUsers: applicableUsersController.text.isEmpty
            ? []
            : applicableUsersController.text.split(',').map((e) => e.trim()).toList(),
        applicableProducts: applicableProductsController.text.isEmpty
            ? []
            : applicableProductsController.text.split(',').map((e) => e.trim()).toList(),
      );

      if (widget.coupon == null) {
        await ref.read(couponManagementProvider).createCoupon(coupon);
      } else {
        await ref.read(couponManagementProvider).updateCoupon(widget.coupon!.id, coupon);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coupon saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectUsers(BuildContext context) async {
    final currentSelected = applicableUsersController.text.isEmpty
        ? <String>[]
        : applicableUsersController.text.split(',').map((e) => e.trim()).toList();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _UserSelectionDialog(
        initialSelection: currentSelected,
      ),
    );

    if (result != null) {
      setState(() {
        applicableUsersController.text = result.join(', ');
      });
    }
  }

  Future<void> _selectProducts(BuildContext context) async {
    final currentSelected = applicableProductsController.text.isEmpty
        ? <String>[]
        : applicableProductsController.text.split(',').map((e) => e.trim()).toList();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _ProductSelectionDialog(
        initialSelection: currentSelected,
      ),
    );

    if (result != null) {
      setState(() {
        applicableProductsController.text = result.join(', ');
      });
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    descriptionController.dispose();
    discountValueController.dispose();
    minAmountController.dispose();
    maxDiscountController.dispose();
    usageLimitController.dispose();
    applicableUsersController.dispose();
    applicableProductsController.dispose();
    super.dispose();
  }
}

class _UserSelectionDialog extends ConsumerStatefulWidget {
  final List<String> initialSelection;

  const _UserSelectionDialog({required this.initialSelection});

  @override
  ConsumerState<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends ConsumerState<_UserSelectionDialog> {
  late Set<String> _selectedEmails;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedEmails = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    
    return AlertDialog(
      title: const Text('Select Specific Users'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  final filtered = users.where((u) {
                    final email = u.email.toLowerCase();
                    final name = (u.name ?? '').toLowerCase();
                    return email.contains(_searchQuery) || name.contains(_searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final isSelected = _selectedEmails.contains(user.email);
                      
                      return CheckboxListTile(
                        title: Text(user.name ?? 'No Name'),
                        subtitle: Text(user.email),
                        value: isSelected,
                        onChanged: (checked) {
                          if (user.email.isEmpty) return;
                          setState(() {
                            if (checked == true) {
                              _selectedEmails.add(user.email);
                            } else {
                              _selectedEmails.remove(user.email);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading users: $err')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedEmails.clear();
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedEmails.toList()),
          child: const Text('Save Selection'),
        ),
      ],
    );
  }
}

class _ProductSelectionDialog extends ConsumerStatefulWidget {
  final List<String> initialSelection;

  const _ProductSelectionDialog({required this.initialSelection});

  @override
  ConsumerState<_ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends ConsumerState<_ProductSelectionDialog> {
  late Set<String> _selectedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    // For products, we use the filteredProductsProvider directly (which supports searching)
    // To feed the search provider, we can just update productsSearchProvider, 
    // but updating provider inside build might have caveats, so a local Future or watching is better.
    // However, since we are inside a dialog, let's watch the provider with the search query directly.
    
    // Set search query in the provider:
    Future.microtask(() {
       ref.read(productsSearchProvider.notifier).state = _searchQuery;
    });

    final productsAsync = ref.watch(filteredProductsProvider);
    
    return AlertDialog(
      title: const Text('Select Specific Products'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Products',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isSelected = _selectedIds.contains(product.id);
                      
                      return CheckboxListTile(
                        title: Text(product.productName),
                        subtitle: Text(product.category ?? 'No category'),
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(product.id);
                            } else {
                              _selectedIds.remove(product.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading products: $err')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedIds.clear();
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () {
            ref.read(productsSearchProvider.notifier).state = '';
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(productsSearchProvider.notifier).state = '';
            Navigator.pop(context, _selectedIds.toList());
          },
          child: const Text('Save Selection'),
        ),
      ],
    );
  }
}
