"""
CRITICAL FIX: The status banner and buttons are repeating because the old structure
is still in place. Need to completely restructure the Quote Request Details section.
"""

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the line where the content children array starts (around line 2540)
# We need to replace the entire isQuoteRequest section

# Read the entire file as string for easier manipulation
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the entire isQuoteRequest section
# The problem is that Status Banner and Action Buttons are being called
# inside the isQuoteRequest condition, which might be evaluated multiple times

# Replace the problematic section with a clean structure
old_structure = '''                  // Status Banner
                  if (!isOldSystem) ...[
                    _buildStatusBanner(widget.quote['status']),
                    const SizedBox(height: 20),
                  ],'''

# This should only appear ONCE at the top, not inside any condition
# Let's ensure it's outside the isQuoteRequest check

# The real issue: Check if there are multiple calls to these in different conditions
# Let me create a completely new clean structure

new_quote_request_section = '''
                    // Quote Request Items Section (for pending requests)
                    if (isQuoteRequest) ...[
                      // Only show items list, NO banners or buttons here
                      if (widget.quote['quote_request_items'] != null &&
                          widget.quote['quote_request_items'].isNotEmpty) ...[
                        _buildSection(
                          'Quote Request Items',
                          Icons.list_alt_outlined,
                          [
                            // Show quote request items with full details
                            ...(widget.quote['quote_request_items'] as List)
                                .map<Widget>((item) => Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${widget.quote['product_name'] ?? 'Product'} - ${item['quality_option_name'] ?? 'Standard'}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildItemDetail(
                                                  'Size/Specification',
                                                  item['quality_option_name'] ??
                                                      'Standard'),
                                              const SizedBox(width: 24),
                                              _buildItemDetail('Quantity',
                                                  '${item['quantity']}'),
                                              const SizedBox(width: 24),
                                              _buildItemDetail('Unit',
                                                  item['unit'] ?? 'units'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ],
                        ),
                      ] else ...[
                        // Empty state message
                        _buildSection(
                          'Quote Request Items',
                          Icons.list_alt_outlined,
                          [
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
                                    Icons.info_outline,
                                    color: Color(0xFF3B82F6),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Your quote request has been submitted and is being reviewed. You will receive pricing details soon.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                    ],'''

# Find the old isQuoteRequest section and replace it
old_section_start = '''                    if (isQuoteRequest) ...[
                      // Quote Request Items'''

if old_section_start in content:
    # Find the end of this section
    start_idx = content.find(old_section_start)
    # Find the matching closing bracket - look for the next major section or end
    # We need to find where this if block ends
    
    # For safety, let's find the next major section (Notes or Action Buttons)
    end_marker = '''                      const SizedBox(height: 24),

                      // Notes'''
    
    end_idx = content.find(end_marker, start_idx)
    
    if end_idx > start_idx:
        # Replace the entire section
        content = content[:start_idx] + new_quote_request_section + content[end_idx:]
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print("✅ Fixed Quote Request Items section!")
        print("  - Removed any banners/buttons from inside item loop")
        print("  - Items now render cleanly in list")
    else:
        print("❌ Could not find end marker")
else:
    print("❌ Could not find start marker")

print("\n🔍 Now checking for duplicate Status Banner calls...")

# Count how many times _buildStatusBanner or similar patterns appear
status_banner_count = content.count('Your quotation request has been submitted')
print(f"Found {status_banner_count} status banner instances")

if status_banner_count > 1:
    print("⚠️  Multiple status banners detected - need manual cleanup")
