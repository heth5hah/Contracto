"""
Fix Quote Request Details screen by removing ALL duplicates and creating clean structure.

FINAL STRUCTURE:
1. Header (with ONE status badge)
2. Request Summary Card (ONCE)
3. Status Banner (ONCE)
4. Quote Request Items (main content)
5. Notes (if available)
6. Action Button (ONCE at bottom)
"""

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove the duplicate "Product Information" section inside isQuoteRequest
# This is lines 2833-2850 approximately
duplicate_product_info = '''                    if (isQuoteRequest) ...[
                      // Product Information
                      _buildSection(
                        'Product Information',
                        Icons.inventory_2_outlined,
                        [
                          _buildDetailRow('Product Name',
                              widget.quote['product_name'] ?? 'Unknown'),
                          if (widget.quote['category'] != null)
                            _buildDetailRow(
                                'Category', widget.quote['category']),
                          _buildDetailRow('Request Date',
                              _formatDate(widget.quote['created_at'])),
                          _buildDetailRow(
                              'Status', widget.quote['status'] ?? 'pending'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Quote Request Items'''

# Replace with just the Quote Request Items section
replacement_items = '''                    if (isQuoteRequest) ...[
                      // Quote Request Items'''

content = content.replace(duplicate_product_info, replacement_items)

# 2. Remove the duplicate status banner that appears inside the pending check
# Find and remove the "Usually takes 24-48 hours" banner
duplicate_pending_banner = '''                        // Placeholder for pricing (will be filled by admin)
                        if (widget.quote['status'] == 'pending') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Color(0xFF3B82F6),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Usually takes 24-48 hours for exact estimate',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],'''

content = content.replace(duplicate_pending_banner, '')

# 3. Remove the old action buttons section (the one for quoted status inside the quote response section)
# This prevents duplicate buttons
old_action_buttons = '''                      // Action Buttons for Quote Response
                      if (widget.quote['quotes'][0]['status'] == 'pending') ...[
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onRejectQuote(widget.quote['id']);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                      ],'''

content = content.replace(old_action_buttons, '')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Removed ALL duplicate elements!")
print("  - Removed duplicate Product Information section")
print("  - Removed duplicate pending status banner")
print("  - Removed duplicate action buttons")
print("\n📋 Final structure:")
print("  1. Header with status badge")
print("  2. Request Summary Card (ONCE)")
print("  3. Status Banner (ONCE)")
print("  4. Quote Request Items")
print("  5. Action Buttons (ONCE at bottom)")
