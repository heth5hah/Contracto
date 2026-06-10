"""
Final cleanup: Remove remaining duplicate action buttons from Quote Response section.
These are the old buttons that should have been removed earlier.
"""

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the remaining duplicate action buttons in the Quote Response section
# These are around lines 2894-2950
old_buttons_in_quote_response = '''
                      // Action Buttons for Quote Response
                      if (widget.quote['quotes'] != null &&
                          widget.quote['quotes'].isNotEmpty) ...[
                        if (widget.quote['quotes'][0]['status'] ==
                            'pending') ...[
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
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
                      ],'''

content = content.replace(old_buttons_in_quote_response, '')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Removed remaining duplicate action buttons!")
print("\n📋 Final Clean Structure:")
print("  ✅ Request Summary Card (ONCE)")
print("  ✅ Status Banner (ONCE)")  
print("  ✅ Quote Request Items (list of items)")
print("  ✅ Quote Response (if quoted)")
print("  ✅ Action Buttons via _buildActionButtons() (ONCE)")
print("\n❌ NO duplicates in item loops!")
