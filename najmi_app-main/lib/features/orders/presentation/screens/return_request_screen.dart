import 'package:flutter/material.dart';
import 'package:contracto_app/features/orders/data/models/order_model.dart';
import 'package:contracto_app/features/orders/data/models/return_model.dart';
import 'package:contracto_app/features/orders/data/services/return_service.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';

class ReturnRequestScreen extends StatefulWidget {
  final OrderModel order;

  const ReturnRequestScreen({super.key, required this.order});

  @override
  State<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  final _returnService = ReturnService();
  final _notesController = TextEditingController();

  // Track selected items and their quantities
  final Map<int, bool> _selectedItems = {};
  final Map<int, int> _itemQuantities = {};

  // Returnable items with remaining quantities
  List<ReturnableItem> _returnableItems = [];
  bool _isLoading = true;

  String _selectedReason = 'Defective/Damaged';
  bool _isSubmitting = false;

  final List<String> _returnReasons = [
    'Defective/Damaged',
    'Wrong item received',
    'Not as described',
    'Changed mind',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadReturnableItems();
  }

  Future<void> _loadReturnableItems() async {
    try {
      final items = await _returnService.getReturnableItems(widget.order);
      if (mounted) {
        setState(() {
          _returnableItems = items;
          // Initialize selection state for returnable items only
          for (int i = 0; i < items.length; i++) {
            _selectedItems[i] = false;
            _itemQuantities[i] = items[i].remainingQty;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading returnable items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _refundAmount {
    double total = 0.0;
    final gstRate = (widget.order.subtotal > 0)
        ? (widget.order.gstAmount / widget.order.subtotal)
        : 0.0;
    _selectedItems.forEach((index, isSelected) {
      if (isSelected && index < _returnableItems.length) {
        final item = _returnableItems[index].orderItem;
        final quantity =
            _itemQuantities[index] ?? _returnableItems[index].remainingQty;
        final itemPrice = item.unitPrice * quantity;
        final itemGst = itemPrice * gstRate;
        final itemRefund = (itemPrice + itemGst) * 0.95;
        total += itemRefund;
      }
    });
    return total;
  }

  bool get _hasSelectedItems {
    return _selectedItems.values.any((selected) => selected);
  }

  bool get _allItemsSelected {
    if (_returnableItems.isEmpty) return false;
    return _selectedItems.values.every((selected) => selected);
  }

  void _toggleSelectAll() {
    final shouldSelectAll = !_allItemsSelected;
    setState(() {
      for (int i = 0; i < _returnableItems.length; i++) {
        _selectedItems[i] = shouldSelectAll;
        // When selecting all, reset each item quantity to its max returnable amount
        if (shouldSelectAll) {
          _itemQuantities[i] = _returnableItems[i].remainingQty;
        }
      }
    });
  }

  Future<void> _submitReturn() async {
    if (!_hasSelectedItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to return'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Validate quantities before submitting
    for (var entry in _selectedItems.entries) {
      if (entry.value && entry.key < _returnableItems.length) {
        final returnableItem = _returnableItems[entry.key];
        final quantity =
            _itemQuantities[entry.key] ?? returnableItem.remainingQty;

        if (quantity <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Return quantity for "${returnableItem.orderItem.productName}" must be at least 1'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
          return;
        }

        if (quantity > returnableItem.remainingQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Cannot return $quantity units of "${returnableItem.orderItem.productName}". Only ${returnableItem.remainingQty} units remaining.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', currentUser.email!)
          .single();

      final userId = userData['id'] as String;

      // Create return items from selected items
      final returnItems = <ReturnItemModel>[];
      _selectedItems.forEach((index, isSelected) {
        if (isSelected && index < _returnableItems.length) {
          final returnableItem = _returnableItems[index];
          final item = returnableItem.orderItem;
          final quantity =
              _itemQuantities[index] ?? returnableItem.remainingQty;

          // Final validation: ensure quantity is within bounds
          final finalQuantity = quantity.clamp(1, returnableItem.remainingQty);

          returnItems.add(ReturnItemModel(
            id: '', // Will be generated by database
            returnId: '', // Will be set by service
            productId: item.productId,
            productName: item.productName,
            quantity: finalQuantity,
            unitPrice: item.unitPrice,
            totalPrice: item.unitPrice * finalQuantity,
            qualityOptionName: item.qualityOptionName.isNotEmpty
                ? item.qualityOptionName
                : null,
            unit: item.unit,
            createdAt: DateTime.now(),
          ));
        }
      });

      await _returnService.submitReturnRequest(
        orderId: widget.order.id,
        userId: userId,
        items: returnItems,
        returnReason: _selectedReason,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Always attempt credit restoration — if the user's credit line was
      // used for this order (even if paymentMethod shows "Bank Transfer (Quote)"),
      // the balance will be restored. If no credit account exists, skips silently.
      final gstRate = (widget.order.subtotal > 0)
          ? (widget.order.gstAmount / widget.order.subtotal)
          : 0.0;
      final refundTotal = returnItems.fold(0.0, (sum, it) {
        final itemPrice = it.totalPrice;
        final itemGst = itemPrice * gstRate;
        final itemRefund = (itemPrice + itemGst) * 0.95;
        return sum + itemRefund;
      });
      if (refundTotal > 0) {
        final creditService = BusinessCreditService();
        final shortId =
            widget.order.id.replaceAll('-', '').substring(0, 8).toUpperCase();
        final restored = await creditService.restoreCreditForReturn(
          orderId: widget.order.id,
          refundAmount: refundTotal,
          description:
              'Return refund - Order #$shortId (${returnItems.map((i) => i.productName.isNotEmpty ? i.productName : (i.qualityOptionName ?? 'Item')).join(', ')})',
        );
        print(restored
            ? '✅ Credit restored: ₹$refundTotal for order ${widget.order.id}'
            : 'ℹ️ No credit account — credit restoration skipped');
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return request submitted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      print('Error submitting return: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit return: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Return Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_returnableItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Return Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No items available for return',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Items may have already been returned or are non-returnable',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Return Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildItemsSelection(),
                  const SizedBox(height: 16),
                  _buildReturnReason(),
                  const SizedBox(height: 16),
                  _buildNotes(),
                  const SizedBox(height: 16),
                  _buildRefundSummary(),
                ],
              ),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select the items you want to return and specify the quantity for each item.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSelection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Items to Return',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                // Select All / Deselect All toggle
                GestureDetector(
                  onTap: _toggleSelectAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _allItemsSelected
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _allItemsSelected
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _allItemsSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 16,
                          color: _allItemsSelected
                              ? const Color(0xFF3B82F6)
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _allItemsSelected ? 'Deselect All' : 'Select All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _allItemsSelected
                                ? const Color(0xFF3B82F6)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _returnableItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final returnableItem = _returnableItems[index];
              final item = returnableItem.orderItem;
              final isSelected = _selectedItems[index] ?? false;
              final quantity =
                  _itemQuantities[index] ?? returnableItem.remainingQty;
              final maxQty = returnableItem.remainingQty;

              // Build the display name: prefer productName, fall back to qualityOptionName
              final displayProductName = item.productName.isNotEmpty
                  ? item.productName
                  : item.qualityOptionName.isNotEmpty
                      ? item.qualityOptionName
                      : 'Item ${index + 1}';

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedItems[index] = !isSelected;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            _selectedItems[index] = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product name (bold)
                            Text(
                              displayProductName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            // Quality sub-label (only if both fields are present)
                            if (item.productName.isNotEmpty &&
                                item.qualityOptionName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.qualityOptionName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            // Show RETURNABLE qty (not original order qty)
                            Text(
                              '₹${item.unitPrice.toStringAsFixed(2)} × $maxQty ${item.unit ?? 'units'} (returnable)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            // Badge if some already returned
                            if (returnableItem.alreadyReturnedQty > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Already returned: ${returnableItem.alreadyReturnedQty} | Remaining: $maxQty',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            // Quantity stepper (shown only when selected)
                            if (isSelected) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text(
                                    'Return Quantity: ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: quantity > 1
                                              ? () {
                                                  setState(() {
                                                    _itemQuantities[index] =
                                                        (quantity - 1)
                                                            .clamp(1, maxQty);
                                                  });
                                                }
                                              : null,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.remove,
                                              size: 16,
                                              color: quantity > 1
                                                  ? Colors.black
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Text(
                                            quantity.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: quantity < maxQty
                                              ? () {
                                                  setState(() {
                                                    _itemQuantities[index] =
                                                        (quantity + 1)
                                                            .clamp(1, maxQty);
                                                  });
                                                }
                                              : null,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.add,
                                              size: 16,
                                              color: quantity < maxQty
                                                  ? Colors.black
                                                  : Colors.grey,
                                            ),
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
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReturnReason() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Return Reason',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: _returnReasons.map((reason) {
              return DropdownMenuItem(
                value: reason,
                child: Text(reason),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedReason = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Notes (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Provide any additional details about the return...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Estimated Refund',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '₹${_refundAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.transparent,
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                _isSubmitting || !_hasSelectedItems ? null : _submitReturn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              disabledBackgroundColor: Colors.grey[200],
              disabledForegroundColor: Colors.grey[400],
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Submit Return Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
