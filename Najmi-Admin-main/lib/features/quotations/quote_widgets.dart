import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quotations_provider.dart';
import 'quotation_model.dart';

void _showEditDialog(BuildContext context, WidgetRef ref, Quotation quote) {
  showDialog(
    context: context,
    builder: (context) => _EditQuoteDialog(quote: quote),
  );
}

class _AdminStatusBadge extends StatelessWidget {
  final String status;

  const _AdminStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'new':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        displayText = 'New';
        break;
      case 'processing':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        displayText = 'Processing';
        break;
      case 'closed':
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        displayText = 'Closed';
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditQuoteDialog extends ConsumerStatefulWidget {
  final Quotation quote;

  const _EditQuoteDialog({required this.quote});

  @override
  ConsumerState<_EditQuoteDialog> createState() => _EditQuoteDialogState();
}

class _EditQuoteDialogState extends ConsumerState<_EditQuoteDialog> {
  late TextEditingController transportController;
  late String selectedStatus;

  @override
  void initState() {
    super.initState();
    transportController = TextEditingController(
      text: widget.quote.transportCharges.toString(),
    );
    selectedStatus = widget.quote.adminStatus;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Quote #${widget.quote.id.substring(0, 8)}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product: ${widget.quote.customerName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: transportController,
              decoration: const InputDecoration(
                labelText: 'Transport Charges (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Admin Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('New')),
                DropdownMenuItem(value: 'processing', child: Text('Processing')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedStatus = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    final transportCharges = double.tryParse(transportController.text) ?? 0.0;

    await ref.read(quoteManagementProvider).updateQuote(
          widget.quote.id,
          transportCharges: transportCharges,
          adminStatus: selectedStatus,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quote updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    transportController.dispose();
    super.dispose();
  }
}
