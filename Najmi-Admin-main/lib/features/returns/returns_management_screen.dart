import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'returns_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class ReturnsManagementScreen extends ConsumerWidget {
  const ReturnsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context, ref),
          Expanded(
            child: returnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (returns) => returns.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: returns.length,
                      itemBuilder: (context, index) =>
                          _ReturnCard(returnReq: returns[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Return Requests',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            Text('Manage customer return & refund requests',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ]),
          IconButton(
            onPressed: () => ref.invalidate(returnsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(100)),
          child: Icon(Icons.assignment_return_outlined,
              size: 56, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        Text('No return requests',
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('When customers submit returns, they will appear here.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReturnCard — one card per return
// ─────────────────────────────────────────────────────────────────────────────
class _ReturnCard extends ConsumerStatefulWidget {
  final ReturnRequest returnReq;
  const _ReturnCard({required this.returnReq});

  @override
  ConsumerState<_ReturnCard> createState() => _ReturnCardState();
}

class _ReturnCardState extends ConsumerState<_ReturnCard> {
  ReturnBankDetails? _bankDetails;
  bool _bankLoading = false;
  bool _bankLoaded = false;

  ReturnRequest get r => widget.returnReq;

  @override
  void initState() {
    super.initState();
    // Auto-load bank details for pickup_scheduled and beyond
    if (_shouldShowBankSection) {
      _loadBankDetails();
    }
  }

  bool get _shouldShowBankSection =>
      r.bankDetailsSubmitted ||
      ['pickup_scheduled', 'picked_up', 'product_received', 'refund_pending', 'refund_completed']
          .contains(r.returnStatus);

  Future<void> _loadBankDetails() async {
    if (_bankLoading || _bankLoaded) return;
    setState(() => _bankLoading = true);
    try {
      final service = ref.read(returnsManagementProvider);
      final details = await service.getBankDetailsDirect(r.id);
      if (mounted) {
        setState(() {
          _bankDetails = details;
          _bankLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _bankLoaded = true);
    }
    if (mounted) setState(() => _bankLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(r.returnStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: EdgeInsets.zero,
          onExpansionChanged: (open) {
            if (open && !_bankLoaded && _shouldShowBankSection) {
              _loadBankDetails();
            }
          },
          title: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${r.orderNumber ?? r.orderId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937)),
                    ),
                    Text(r.customerName ?? 'Unknown Customer',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ]),
            ),
            _StatusBadge(status: r.returnStatus),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6, left: 20),
            child: Row(children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(DateFormat('dd MMM yyyy').format(r.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(width: 12),
              const Icon(Icons.currency_rupee, size: 12, color: Color(0xFF10B981)),
              Text(r.refundAmount.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981))),
            ]),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Return info
                    _buildReturnInfoSection(),
                    const SizedBox(height: 16),

                    // 2. Items
                    _buildItemsSection(),
                    const SizedBox(height: 16),

                    // 3. Bank Details (ALWAYS shown, not conditional on flag)
                    _buildBankDetailsSection(),
                    const SizedBox(height: 16),

                    // 4. Pickup Tracker (shown when approved or beyond)
                    if (['approved', 'pickup_scheduled', 'picked_up',
                        'product_received', 'refund_pending',
                        'refund_completed'].contains(r.returnStatus)) ...[
                      _buildPickupTracker(),
                      const SizedBox(height: 16),
                    ],

                    // 5. Refund Completed info
                    if (r.returnStatus == 'refund_completed')
                      _buildRefundCompletedSection(),

                    // 6. Action Buttons
                    _buildActions(context, ref),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Return Info ─────────────────────────────────────────────────────────────
  Widget _buildReturnInfoSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Return Details', Icons.assignment_return),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('Reason', r.returnReason ?? 'Not specified'),
          if (r.notes != null && r.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _infoRow('Notes', r.notes!),
          ],
          if (r.rejectionReason != null) ...[
            const SizedBox(height: 4),
            _infoRow('Rejection Reason', r.rejectionReason!,
                valueColor: const Color(0xFFEF4444)),
          ],
          const SizedBox(height: 4),
          _infoRow('Requested On', DateFormat('dd MMM yyyy, hh:mm a').format(r.createdAt)),
          const SizedBox(height: 4),
          _infoRow('Est. Refund', '₹${r.refundAmount.toStringAsFixed(2)}',
              valueColor: const Color(0xFF10B981), bold: true),
        ]),
      ),
    ]);
  }

  // ── Items ───────────────────────────────────────────────────────────────────
  Widget _buildItemsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Returned Items', Icons.inventory_2_outlined),
      const SizedBox(height: 8),
      ...r.items.map((item) => Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(item.productName,
                      style: const TextStyle(fontSize: 13))),
              Text(
                  '${item.quantity.toInt()} × ₹${item.unitPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              Text('₹${item.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          )),
    ]);
  }

  // ── Bank Details ────────────────────────────────────────────────────────────
  Widget _buildBankDetailsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Customer Bank Details', Icons.account_balance),
      const SizedBox(height: 8),
      if (!r.bankDetailsSubmitted && !_shouldShowBankSection)
        // Not in a stage where customer would submit
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(children: [
            Icon(Icons.hourglass_empty,
                size: 16, color: Color(0xFF94A3B8)),
            SizedBox(width: 8),
            Text('Not yet applicable — await approval first',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ]),
        )
      else if (_bankLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        )
      else if (_bankDetails == null && _bankLoaded)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.pending_actions,
                size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⏳ Waiting for customer to submit bank details',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF92400E))),
                    const SizedBox(height: 2),
                    Text(
                        r.bankDetailsSubmitted
                            ? 'Submitted ✓ — loading details...'
                            : 'Customer has not submitted yet',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFB45309))),
                  ]),
            ),
            TextButton.icon(
              onPressed: _loadBankDetails,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ]),
        )
      else if (_bankDetails != null)
        _buildBankDetailsCard(_bankDetails!),
    ]);
  }

  Widget _buildBankDetailsCard(ReturnBankDetails bank) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.account_balance, color: Color(0xFF3B82F6), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Bank Details Submitted ✔',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                    fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFBFDBFE), height: 1),
        const SizedBox(height: 12),
        _bankRow(Icons.person, 'Account Holder', bank.accountHolderName),
        const SizedBox(height: 8),
        _bankRow(Icons.account_balance, 'Bank Name', bank.bankName),
        const SizedBox(height: 8),
        // Account number with full number (admin can see) + copy button
        Row(children: [
          const Icon(Icons.credit_card, size: 16, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          const SizedBox(
              width: 110,
              child: Text('Account No.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(
            child: Row(children: [
              Text(
                bank.accountNumber,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    letterSpacing: 1.5),
              ),
              const SizedBox(width: 8),
              // Copy button for the actual number
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: bank.accountNumber));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Account number copied'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(children: [
                    Icon(Icons.copy, size: 11, color: Color(0xFF3B82F6)),
                    SizedBox(width: 3),
                    Text('Copy',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        _bankRow(Icons.code, 'IFSC Code', bank.ifscCode),
        if (bank.upiId != null && bank.upiId!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _bankRow(Icons.phone_android, 'UPI ID', bank.upiId!),
        ],
      ]),
    );
  }

  Widget _bankRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
      const SizedBox(width: 8),
      SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B)))),
    ]);
  }

  // ── Pickup Progress Tracker ─────────────────────────────────────────────────
  Widget _buildPickupTracker() {
    final dateStr = r.pickupDate != null
        ? DateFormat('dd MMM yyyy').format(r.pickupDate!)
        : null;

    final inProcess = ['pickup_scheduled', 'picked_up', 'product_received',
        'refund_pending', 'refund_completed'].contains(r.returnStatus);
    final pickedUp = ['picked_up', 'product_received', 'refund_pending',
        'refund_completed'].contains(r.returnStatus);
    final received = ['product_received', 'refund_pending',
        'refund_completed'].contains(r.returnStatus);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Pickup Progress', Icons.local_shipping),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(children: [
          // Step 1: Pickup Date
          _pickupStep(
            icon: Icons.calendar_today,
            title: 'Pickup Date',
            subtitle: dateStr != null
                ? 'Scheduled for $dateStr'
                : r.returnStatus == 'approved'
                    ? 'Tap to set pickup date'
                    : 'Date not set',
            isDone: dateStr != null,
            isCurrent: r.returnStatus == 'approved' && dateStr == null,
            actionWidget: r.returnStatus == 'approved'
                ? _actionButton(
                    label: dateStr != null ? 'Change Date' : 'Set Pickup Date',
                    icon: Icons.edit_calendar,
                    color: const Color(0xFF3B82F6),
                    onTap: () => _pickDateDialog(context, ref),
                  )
                : null,
          ),
          _trackerConnector(isDone: inProcess),

          // Step 2: In Process (Pickup Scheduled → Item picked up)
          _pickupStep(
            icon: Icons.sync,
            title: 'Pickup In Progress',
            subtitle: inProcess && !pickedUp
                ? 'On the way to pick up the product'
                : pickedUp
                    ? 'Successfully en route to warehouse'
                    : 'Awaiting pickup date',
            isDone: pickedUp,
            isCurrent: inProcess && !pickedUp,
            actionWidget: r.returnStatus == 'pickup_scheduled'
                ? _actionButton(
                    label: 'Mark Picked Up ✓',
                    icon: Icons.local_shipping,
                    color: const Color(0xFF06B6D4),
                    onTap: () => _doAction(
                        context,
                        ref,
                        () => ref
                            .read(returnsManagementProvider)
                            .markPickedUp(r.id),
                        'Marked as Picked Up'),
                  )
                : null,
          ),
          _trackerConnector(isDone: pickedUp),

          // Step 3: Pickup Successful → Product Received
          _pickupStep(
            icon: Icons.inventory_2,
            title: 'Pickup Successful',
            subtitle: pickedUp && !received
                ? 'Inspect product at warehouse'
                : received
                    ? 'Product received at warehouse ✔'
                    : 'Pending',
            isDone: received,
            isCurrent: pickedUp && !received,
            isLast: true,
            actionWidget: r.returnStatus == 'picked_up'
                ? _actionButton(
                    label: 'Mark Product Received',
                    icon: Icons.inventory,
                    color: const Color(0xFFEA580C),
                    onTap: () => _doAction(
                        context,
                        ref,
                        () => ref
                            .read(returnsManagementProvider)
                            .markProductReceived(r.id),
                        'Product Received — Refund Pending'),
                  )
                : null,
          ),
        ]),
      ),
    ]);
  }

  Widget _pickupStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
    bool isCurrent = false,
    bool isLast = false,
    Widget? actionWidget,
  }) {
    final color = isDone
        ? const Color(0xFF10B981)
        : isCurrent
            ? const Color(0xFF3B82F6)
            : const Color(0xFFCBD5E1);

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(isDone || isCurrent ? 0.15 : 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: isDone ? 0 : 2),
        ),
        child: Icon(isDone ? Icons.check : icon,
            color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : isCurrent
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF94A3B8))),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 11,
                  color: isDone || isCurrent
                      ? const Color(0xFF64748B)
                      : const Color(0xFFCBD5E1))),
          if (actionWidget != null) ...[
            const SizedBox(height: 8),
            actionWidget,
          ],
          if (!isLast) const SizedBox(height: 8),
        ]),
      ),
    ]);
  }

  Widget _trackerConnector({required bool isDone}) {
    return Padding(
      padding: const EdgeInsets.only(left: 17, top: 2, bottom: 2),
      child: Container(
        width: 2,
        height: 28,
        color: isDone
            ? const Color(0xFF10B981)
            : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  // ── Refund Completed Section ─────────────────────────────────────────────────
  Widget _buildRefundCompletedSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
          SizedBox(width: 8),
          Text('Refund Processed ✔',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                  fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        if (r.refundAmountFinal > 0)
          _infoRow('Amount Refunded', '₹${r.refundAmountFinal.toStringAsFixed(2)}',
              valueColor: const Color(0xFF10B981), bold: true),
        if (r.refundTransactionId != null) ...[
          const SizedBox(height: 4),
          _infoRow('Transaction ID', r.refundTransactionId!),
        ],
        if (r.refundProcessedAt != null) ...[
          const SizedBox(height: 4),
          _infoRow('Processed On',
              DateFormat('dd MMM yyyy, hh:mm a').format(r.refundProcessedAt!)),
        ],
      ]),
    );
  }

  // ── Action Buttons ──────────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context, WidgetRef ref) {
    switch (r.returnStatus) {
      case 'pending':
        return Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRejectDialog(context, ref),
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Reject',
                  style: TextStyle(color: Color(0xFFEF4444))),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showApproveDialog(context, ref),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve & Set Pickup'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white),
            ),
          ),
        ]);

      case 'approved':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _pickDateDialog(context, ref),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text('Set Pickup Date'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white),
          ),
        );

      case 'pickup_scheduled':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _doAction(
                context,
                ref,
                () => ref.read(returnsManagementProvider).markPickedUp(r.id),
                'Marked as Picked Up ✔'),
            icon: const Icon(Icons.local_shipping, size: 16),
            label: const Text('Mark as Picked Up'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white),
          ),
        );

      case 'picked_up':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _doAction(
                context,
                ref,
                () => ref.read(returnsManagementProvider).markProductReceived(r.id),
                'Product Received ✔'),
            icon: const Icon(Icons.inventory, size: 16),
            label: const Text('Mark Product Received'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white),
          ),
        );

      case 'refund_pending':
      case 'product_received':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showProcessRefundDialog(context, ref),
            icon: const Icon(Icons.payments, size: 16),
            label: const Text('Process Refund'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────
  Future<void> _showApproveDialog(BuildContext context, WidgetRef ref) async {
    int pickupDays = 3;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Approve Return'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Customer: ${r.customerName ?? 'Unknown'}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text('Est. Refund: ₹${r.refundAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('Pickup within (working days):',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  onPressed: pickupDays > 1 ? () => setState(() => pickupDays--) : null,
                  icon: const Icon(Icons.remove_circle_outline)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$pickupDays',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                  onPressed: pickupDays < 14 ? () => setState(() => pickupDays++) : null,
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color(0xFF10B981))),
              const Text(' days'),
            ]),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref
                    .read(returnsManagementProvider)
                    .approveReturn(r.id, pickupDays);
                if (context.mounted) {
                  _showSnack(context, ok ? 'Return approved ✔' : 'Failed', ok);
                }
              },
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateDialog(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Select Pickup Date',
    );
    if (picked != null) {
      final ok = await ref.read(returnsManagementProvider).setPickupDate(r.id, picked);
      if (context.mounted) {
        _showSnack(
            context,
            ok ? 'Pickup date set: ${DateFormat('dd MMM yyyy').format(picked)}' : 'Failed',
            ok);
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Return'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Please provide a reason for rejection:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Product not eligible for return...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              Navigator.pop(ctx);
              final ok = await ref
                  .read(returnsManagementProvider)
                  .rejectReturn(r.id, reason.isEmpty ? 'No reason provided' : reason);
              if (context.mounted) {
                _showSnack(context,
                    ok ? 'Return rejected' : 'Failed to reject', ok);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProcessRefundDialog(
      BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController(
        text: r.refundAmount.toStringAsFixed(2));
    final txnCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Process Refund'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_bankDetails != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Refund to:',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(_bankDetails!.accountHolderName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8))),
                    Text(
                        '${_bankDetails!.bankName} • ${_bankDetails!.maskedAccountNumber}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF3B82F6))),
                  ]),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Refund Amount (₹)',
              prefixIcon: const Icon(Icons.currency_rupee, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: txnCtrl,
            decoration: InputDecoration(
              labelText: 'Transaction Reference ID',
              prefixIcon: const Icon(Icons.tag, size: 18),
              hintText: 'Bank transfer reference number',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.payments, size: 16),
            label: const Text('Confirm Refund'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              final txn = txnCtrl.text.trim();
              if (amount <= 0) return;
              Navigator.pop(ctx);
              final ok = await ref
                  .read(returnsManagementProvider)
                  .processRefund(r.id, amount, txn.isEmpty ? 'N/A' : txn);
              if (context.mounted) {
                _showSnack(
                    context,
                    ok
                        ? '✔ Refund of ₹$amount processed'
                        : 'Failed',
                    ok);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Future<void> _doAction(BuildContext context, WidgetRef ref,
      Future<bool> Function() action, String successMsg) async {
    final ok = await action();
    if (context.mounted) _showSnack(context, ok ? successMsg : 'Action failed', ok);
  }

  void _showSnack(BuildContext context, String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF64748B)),
      const SizedBox(width: 6),
      Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151))),
    ]);
  }

  Widget _infoRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 90,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
      Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ?? const Color(0xFF1F2937)))),
    ]);
  }

  Color _statusColor(String status) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(_text(status),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  String _text(String s) {
    switch (s) {
      case 'pending':          return 'Pending';
      case 'approved':         return 'Approved';
      case 'rejected':         return 'Rejected';
      case 'pickup_scheduled': return 'Pickup Scheduled';
      case 'picked_up':        return 'Picked Up';
      case 'product_received': return 'Product Received';
      case 'refund_pending':   return 'Refund Pending';
      case 'refund_completed': return 'Refund Done ✔';
      case 'completed':        return 'Completed';
      case 'cancelled':        return 'Cancelled';
      default:                 return s;
    }
  }

  Color _color(String s) {
    switch (s) {
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
}
