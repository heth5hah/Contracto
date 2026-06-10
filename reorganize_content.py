file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the duplicate Product Information section (lines 2427-2442 approximately)
# This is the section that appears BEFORE the isQuoteRequest check
duplicate_section = '''                  ] else ...[
                    // Product Information - always show for quotes with data
                    _buildSection(
                      'Product Information',
                      Icons.inventory_2_outlined,
                      [
                        _buildDetailRow('Product Name',
                            widget.quote['product_name'] ?? 'Unknown'),
                        if (widget.quote['category'] != null)
                          _buildDetailRow('Category', widget.quote['category']),
                        _buildDetailRow('Request Date',
                            _formatDate(widget.quote['created_at'])),
                        _buildDetailRow(
                            'Status', widget.quote['status'] ?? 'pending'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quote Response (if available) - moved outside isQuoteRequest condition'''

# Replace with just the Quote Response section
replacement = '''                  ] else ...[
                    // Quote Response (if available) - moved outside isQuoteRequest condition'''

content = content.replace(duplicate_section, replacement)

# Now update the content section to add Request Summary and Status Banner at the beginning
# Find the start of the content children array
old_content_start = '''              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show message when quote is ready but data is missing
                  if (isQuotedButNoData) ...['''

new_content_start = '''              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Request Summary Card
                  if (!isOldSystem) ...[
                    _buildRequestSummaryCard(),
                    const SizedBox(height: 20),
                  ],
                  
                  // Status Banner
                  if (!isOldSystem) ...[
                    _buildStatusBanner(widget.quote['status']),
                    const SizedBox(height: 20),
                  ],
                  
                  // Show message when quote is ready but data is missing
                  if (isQuotedButNoData) ...['''

content = content.replace(old_content_start, new_content_start)

# Add action buttons at the end, before the closing brackets
# Find the end of the content section (before the last closing brackets)
old_content_end = '''                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }'''

new_content_end = '''                  ],
                  
                  // Action Buttons
                  if (!isOldSystem) ...[
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }'''

content = content.replace(old_content_end, new_content_end)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Reorganized content structure!")
print("  - Removed duplicate Product Information section")
print("  - Added Request Summary Card")
print("  - Added Status Banner")
print("  - Added Action Buttons at bottom")
