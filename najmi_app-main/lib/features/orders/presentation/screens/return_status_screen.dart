import 'package:flutter/material.dart';
import 'package:contracto_app/features/orders/data/models/return_model.dart';
import 'package:contracto_app/features/orders/data/services/return_service.dart';
import 'package:intl/intl.dart';
import 'submit_bank_details_screen.dart';

/// Shows the full return timeline and current status for a customer
class ReturnStatusScreen extends StatefulWidget {
  final ReturnModel returnModel;
  const ReturnStatusScreen({super.key, required this.returnModel});

  @override
  State<ReturnStatusScreen> createState() => _ReturnStatusScreenState();
}

class _ReturnStatusScreenState extends State<ReturnStatusScreen> {
  late ReturnModel _return;
  final _returnService = ReturnService();
  bool _isLoading = false;
  ReturnBankDetails? _bankDetails;
  bool _bankLoaded = false;
  bool _bankLoading = false;

  // Statuses where bank details CAN exist / be submitted
  static const _bankStatuses = [
    'approved', 'pickup_scheduled', 'picked_up',
    'product_received', 'refund_pending', 'refund_completed', 'completed',
  ];

  // Cancel only allowed while pending OR approved (before pickup begins)
  bool get _canCancel =>
      _return.returnStatus == 'pending' || _return.returnStatus == 'approved';

  @override
  void initState() {
    super.initState();
    _return = widget.returnModel;
    _refresh();
  }

  Future<void> _refresh() async {
    // Reset bank state so the spinner shows during reload
    setState(() {
      _isLoading = true;
      _bankLoaded = false;
      _bankDetails = null;
    });
    try {
      print('DEBUG: _refresh() fetching return ${_return.id}');
      final updated = await _returnService.getReturnById(_return.id);
      print('DEBUG: got return status=${updated.returnStatus} bankDetailsSubmitted=${updated.bankDetailsSubmitted}');
      if (mounted) setState(() => _return = updated);
      if (_bankStatuses.contains(updated.returnStatus)) {
        print('DEBUG: status in bankStatuses, loading bank details...');
        await _loadBankDetails();
        print('DEBUG: bank details loaded: ${_bankDetails != null}');
      } else {
        if (mounted) setState(() { _bankLoaded = true; });
      }
    } catch (e) {
      print('ERROR: _refresh failed: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadBankDetails({bool force = false}) async {
    if (_bankLoading || (_bankLoaded && !force)) return;
    if (mounted) setState(() { _bankLoading = true; _bankLoaded = false; });
    try {
      final bank = await _returnService.getBankDetails(_return.id);
      if (mounted) setState(() { _bankDetails = bank; _bankLoaded = true; });
    } catch (e) {
      print('_loadBankDetails error: $e');
      if (mounted) setState(() { _bankLoaded = true; });
    }
    if (mounted) setState(() => _bankLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Return #${_return.id.substring(0, 8).toUpperCase()}'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),

                  // Return progress timeline
                  if (_return.returnStatus != 'rejected' &&
                      _return.returnStatus != 'cancelled')
                    _buildTimeline(),
                  if (_return.returnStatus != 'rejected' &&
                      _return.returnStatus != 'cancelled')
                    const SizedBox(height: 16),

                  // Bank details section
                  if (_bankStatuses.contains(_return.returnStatus))
                    _buildBankSection(),

                  // Rejection card
                  if (_return.returnStatus == 'rejected') _buildRejectionCard(),

                  // Refund success
                  if (_return.isCompleted) _buildRefundSuccessCard(),

                  const SizedBox(height: 16),
                  _buildItemsCard(),

                  // Cancel button (with disabled state if already actioned)
                  if (!_return.isCompleted &&
                      _return.returnStatus != 'rejected' &&
                      _return.returnStatus != 'cancelled') ...[
                    const SizedBox(height: 16),
                    _buildCancelButton(),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Status Card ──────────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final color = _getStatusColor(_return.returnStatus);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_getStatusIcon(_return.returnStatus), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_return.statusText,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(_getStatusDescription(_return),
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ])),
        ]),
        if (_bankStatuses.contains(_return.returnStatus) && _return.pickupDays > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.local_shipping, color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 8),
              Text('Pickup within ${_return.pickupDays} working days',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF64748B)),
          Text(' Estimated Refund: ₹${_return.refundAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ]),
      ]),
    );
  }

  // ── Timeline ─────────────────────────────────────────────────────────────────
  Widget _buildTimeline() {
    final steps = [
      const _TimelineStep('Requested', 'Return request submitted', Icons.assignment_add),
      const _TimelineStep('Approved', 'Admin reviewed & approved', Icons.check_circle),
      const _TimelineStep('Bank Details', 'Bank details submitted for refund', Icons.account_balance),
      _TimelineStep('Picked Up', _return.pickupDate != null ? 'Scheduled for ${DateFormat('dd MMM yyyy').format(_return.pickupDate!)}' : 'Product collected from you', Icons.local_shipping),
      const _TimelineStep('Product Received', 'Warehouse inspecting your product', Icons.inventory),
      const _TimelineStep('Refund Processed', 'Money sent to your account', Icons.payments),
    ];

    final currentStep = _return.timelineStep;
    final isRejected = _return.returnStatus == 'rejected' ||
        _return.returnStatus == 'cancelled';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Return Progress',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 16),
        if (isRejected)
          _buildRejectedStep()
        else
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isDone = i < currentStep;
            final isCurrent = i == currentStep;
            final isPending = i > currentStep;
            final isLast = i == steps.length - 1;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF10B981)
                        : isCurrent
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFE2E8F0),
                  ),
                  child: Icon(isDone ? Icons.check : step.icon,
                      color: isDone || isCurrent ? Colors.white : Colors.grey, size: 18),
                ),
                if (!isLast)
                  Container(
                      width: 2, height: 40,
                      color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Padding(
                padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(step.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isDone
                              ? const Color(0xFF10B981)
                              : isCurrent ? const Color(0xFF3B82F6) : Colors.grey)),
                  Text(step.subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isPending ? Colors.grey[400] : Colors.grey[600])),
                ]),
              )),
            ]);
          }),
      ]),
    );
  }

  Widget _buildRejectedStep() {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444)),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _return.returnStatus == 'cancelled' ? 'Return Cancelled' : 'Return Rejected',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
        ),
        Text(
          _return.returnStatus == 'cancelled'
              ? 'You cancelled this return request'
              : 'Your return request was not approved',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ])),
    ]);
  }

  // ── Bank Details Section ─────────────────────────────────────────────────────
  Widget _buildBankSection() {
    // Only relevant for these statuses
    if (!_bankStatuses.contains(_return.returnStatus)) {
      return const SizedBox.shrink();
    }

    // Still loading → show spinner  
    if (_bankLoading || !_bankLoaded) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Center(child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    // Bank details found in DB → show card (regardless of bankDetailsSubmitted flag)
    if (_bankDetails != null) {
      return _buildBankCard(_bankDetails!);
    }

    // No bank details in DB → show submit prompt (only when status allows it)
    if (_return.returnStatus == 'approved') {
      return _buildBankPrompt();
    }

    // Any other status but no bank details yet — show a soft message
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() => _bankLoaded = false);
          _loadBankDetails();
        },
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Tap to Reload Bank Details'),
      ),
    );
  }

  Widget _buildBankPrompt() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.account_balance, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Text('Action Required',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Your return is approved! Please submit your bank details so we can process your refund.',
          style: TextStyle(color: Color(0xFF78350F), fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SubmitBankDetailsScreen(returnId: _return.id)));
              if (result == true) _refresh();
            },
            icon: const Icon(Icons.account_balance_wallet, size: 18),
            label: const Text('Submit Bank Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBankCard(ReturnBankDetails bank) {
    // Allow edit/delete only while pickup not yet started
    final canEdit = ['approved', 'pickup_scheduled'].contains(_return.returnStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title — flexible so it never overflows
          const Expanded(
            child: Row(children: [
              Icon(Icons.account_balance, color: Color(0xFF3B82F6), size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text('Bank Details ✔',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                        fontSize: 14)),
              ),
            ]),
          ),
          // Edit / Delete stacked vertically to prevent overflow
          if (canEdit)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => SubmitBankDetailsScreen(
                          returnId: _return.id, existingDetails: bank)));
                  if (result == true) _refresh();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined, size: 13, color: Color(0xFF3B82F6)),
                    SizedBox(width: 4),
                    Text('Edit', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _confirmDeleteBank(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline, size: 13, color: Color(0xFFEF4444)),
                    SizedBox(width: 4),
                    Text('Delete', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _bankRow('Account Holder', bank.accountHolderName),
        _bankRow('Bank', bank.bankName),
        _bankRow('Account No.', bank.maskedAccountNumber),
        _bankRow('IFSC Code', bank.ifscCode),
        if (bank.upiId != null && bank.upiId!.isNotEmpty)
          _bankRow('UPI ID', bank.upiId!),
      ]),
    );
  }

  Widget _bankRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
    ]),
  );

  Future<void> _confirmDeleteBank() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bank Details?'),
        content: const Text(
            'This will remove your bank details. You can add new details after deletion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _returnService.deleteBankDetails(_return.id);
        if (mounted) {
          // Immediately hide the bank card — don't wait for full refresh
          setState(() {
            _bankDetails = null;
            _bankLoaded = true;
            // Locally update the return model so bankDetailsSubmitted=false
            _return = ReturnModel(
              id: _return.id,
              orderId: _return.orderId,
              userId: _return.userId,
              returnStatus: 'approved',
              returnReason: _return.returnReason,
              description: _return.description,
              notes: _return.notes,
              refundAmount: _return.refundAmount,
              refundAmountFinal: _return.refundAmountFinal,
              pickupDays: _return.pickupDays,
              bankDetailsSubmitted: false,  // <-- key change
              rejectionReason: _return.rejectionReason,
              refundTransactionId: _return.refundTransactionId,
              refundProcessedAt: _return.refundProcessedAt,
              items: _return.items,
              createdAt: _return.createdAt,
              updatedAt: DateTime.now(),
            );
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Bank details removed. You can add new details now.'),
                backgroundColor: Color(0xFF64748B)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // ── Rejection Card ───────────────────────────────────────────────────────────
  Widget _buildRejectionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.cancel, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Text('Return Rejected',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 15)),
        ]),
        if (_return.rejectionReason != null) ...[
          const SizedBox(height: 8),
          Text('Reason: ${_return.rejectionReason}',
              style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13)),
        ],
        const SizedBox(height: 8),
        const Text('Please contact our support team if you believe this is an error.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ]),
    );
  }

  // ── Refund Success ───────────────────────────────────────────────────────────
  Widget _buildRefundSuccessCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.check_circle, color: Color(0xFF10B981)),
          SizedBox(width: 8),
          Text('Refund Processed!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        if (_return.refundAmountFinal > 0)
          Text('₹${_return.refundAmountFinal.toStringAsFixed(2)} has been sent to your bank account.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF064E3B))),
        if (_return.refundTransactionId != null) ...[
          const SizedBox(height: 4),
          Text('Reference ID: ${_return.refundTransactionId}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF047857))),
        ],
        const SizedBox(height: 4),
        const Text('Please allow 2–5 business days for the amount to reflect.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ]),
    );
  }

  // ── Items Card ───────────────────────────────────────────────────────────────
  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Returned Items',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),
        ..._return.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(child: Text(item.displayName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
            Text('${item.quantity} × ₹${item.unitPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ]),
        )),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Estimated Refund', style: TextStyle(fontWeight: FontWeight.w600)),
          Text('₹${_return.refundAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 15)),
        ]),
      ]),
    );
  }

  // ── Cancel Button ────────────────────────────────────────────────────────────
  Widget _buildCancelButton() {
    return Opacity(
      opacity: _canCancel ? 1.0 : 0.4,
      child: OutlinedButton.icon(
        onPressed: _canCancel ? () => _confirmCancel() : null,
        icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 18),
        label: Text(
          _canCancel
              ? 'Cancel Return Request'
              : 'Cannot Cancel — Pickup In Progress',
          style: const TextStyle(color: Color(0xFFEF4444)),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFEF4444)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Return?'),
        content: const Text('Are you sure you want to cancel this return request? Your bank details will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _returnService.cancelReturn(_return.id);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Return request cancelled'),
                backgroundColor: Color(0xFF64748B)),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':          return const Color(0xFFF59E0B);
      case 'approved':         return const Color(0xFF3B82F6);
      case 'pickup_scheduled': return const Color(0xFF8B5CF6);
      case 'picked_up':        return const Color(0xFF06B6D4);
      case 'product_received':
      case 'refund_pending':   return const Color(0xFFEA580C);
      case 'refund_completed':
      case 'completed':        return const Color(0xFF10B981);
      case 'rejected':
      case 'cancelled':        return const Color(0xFFEF4444);
      default:                 return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':          return Icons.hourglass_empty;
      case 'approved':         return Icons.thumb_up;
      case 'pickup_scheduled': return Icons.account_balance;
      case 'picked_up':        return Icons.local_shipping;
      case 'product_received': return Icons.inventory;
      case 'refund_pending':   return Icons.pending_actions;
      case 'refund_completed':
      case 'completed':        return Icons.check_circle;
      case 'rejected':         return Icons.cancel;
      case 'cancelled':        return Icons.block;
      default:                 return Icons.help_outline;
    }
  }

  String _getStatusDescription(ReturnModel r) {
    switch (r.returnStatus) {
      case 'pending':          return 'Waiting for admin review';
      case 'approved':         return r.bankDetailsSubmitted
          ? 'Pickup scheduled within ${r.pickupDays} days'
          : 'Please submit your bank details';
      case 'pickup_scheduled': return 'Our team will pick up within ${r.pickupDays} days';
      case 'picked_up':        return 'Product collected. Warehouse verifying...';
      case 'product_received': return 'Product received. Refund will be processed shortly';
      case 'refund_pending':   return 'Refund being processed — allow 2 working days';
      case 'refund_completed':
      case 'completed':        return 'Refund successfully sent to your account';
      case 'rejected':         return r.rejectionReason ?? 'Return request was not approved';
      case 'cancelled':        return 'Return request was cancelled by you';
      default:                 return '';
    }
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final IconData icon;
  const _TimelineStep(this.title, this.subtitle, this.icon);
}
