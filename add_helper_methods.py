file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the line after _getStatusIcon method (line 2195)
insert_position = 2195  # After line 2195 (0-indexed would be 2194)

new_methods = '''
  Widget _buildRequestSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Request ID', widget.quote['id']?.substring(0, 8) ?? 'N/A'),
            const SizedBox(height: 12),
            _buildSummaryRow('Request Date', _formatDate(widget.quote['created_at'])),
            const SizedBox(height: 12),
            _buildSummaryRow('Status', widget.quote['status'] ?? 'pending'),
            if (widget.quote['brand_name'] != null) ...[
              const SizedBox(height: 12),
              _buildSummaryRow('Supplier', widget.quote['brand_name']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(String? status) {
    String message;
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (status?.toLowerCase()) {
      case 'pending':
        message = 'Your quotation request has been submitted and is under review. Pricing details will be shared soon.';
        bgColor = const Color(0xFFFFF7ED);
        borderColor = const Color(0xFFFFEDD5);
        textColor = const Color(0xFF92400E);
        icon = Icons.schedule;
        break;
      case 'quoted':
        message = 'Quotation received. Please review the pricing details.';
        bgColor = const Color(0xFFF0F9FF);
        borderColor = const Color(0xFFBFDBFE);
        textColor = const Color(0xFF1E40AF);
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
      case 'rejected':
        message = 'This quotation request has been cancelled.';
        bgColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        textColor = const Color(0xFF991B1B);
        icon = Icons.cancel_outlined;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = widget.quote['status']?.toLowerCase();
    
    if (status == 'pending') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            // Show cancel confirmation
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Request?'),
                content: const Text('Are you sure you want to cancel this quotation request?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      // TODO: Implement cancel request functionality
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Yes, Cancel'),
                  ),
                ],
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Cancel Request',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (status == 'quoted' && widget.quote['quotes'] != null && widget.quote['quotes'].isNotEmpty) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onAcceptQuote(widget.quote['id']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Accept Quote',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRejectQuote(widget.quote['id']);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reject Quote',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return const SizedBox.shrink(); // No buttons for cancelled/other statuses
  }

'''

# Insert the new methods
lines.insert(insert_position, new_methods)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✅ Added helper methods for Request Summary, Status Banner, and Action Buttons!")
