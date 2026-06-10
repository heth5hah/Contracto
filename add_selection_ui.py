#!/usr/bin/env python3
"""Script to add selection mode UI to quotations screen"""

import re

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add selection UI buttons in header (after line with "Manual refresh button")
header_pattern = r'(\s+)(\),\s+\),\s+// Manual refresh button\s+IconButton\()'
header_replacement = r'''\1),
\1),
\1// Selection mode toggle and delete selected buttons
\1if (_isSelectionMode) ...[
\1  if (_selectedQuotationIds.isNotEmpty)
\1    IconButton(
\1      onPressed: _deleteSelectedQuotes,
\1      icon: const Icon(Icons.delete_forever),
\1      tooltip: 'Delete Selected (${_selectedQuotationIds.length})',
\1      color: Colors.red,
\1    ),
\1  IconButton(
\1    onPressed: _toggleSelectionMode,
\1    icon: const Icon(Icons.close),
\1    tooltip: 'Cancel Selection',
\1    color: Colors.grey[600],
\1  ),
\1] else
\1  IconButton(
\1    onPressed: _toggleSelectionMode,
\1    icon: const Icon(Icons.checklist),
\1    tooltip: 'Select Multiple',
\1    color: const Color(0xFF8B5CF6),
\1  ),
\1// Manual refresh button
\1IconButton('''

content = re.sub(header_pattern, header_replacement, content, count=1)

# 2. Add checkbox to quotation cards (in _buildQuoteCard method)
# Find the GestureDetector and add checkbox before the card content
card_pattern = r'(return GestureDetector\(\s+onTap: \(\) => _showQuoteDetails\(quotation\),\s+child: AnimatedContainer\(\s+duration: Duration\(milliseconds: 300 \+ \(index \* 50\)\),\s+curve: Curves\.easeOutCubic,\s+decoration: BoxDecoration\(\s+color: Colors\.white,)'

card_replacement = r'''return GestureDetector(
      onTap: _isSelectionMode 
          ? () => _toggleQuotationSelection(quotation['id'])
          : () => _showQuoteDetails(quotation),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300 + (index * 50)),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _isSelectionMode && _selectedQuotationIds.contains(quotation['id'])
              ? const Color(0xFFF0F9FF)
              : Colors.white,
          border: _isSelectionMode && _selectedQuotationIds.contains(quotation['id'])
              ? Border.all(color: const Color(0xFF3B82F6), width: 2)
              : null,'''

# This is complex, let's do a simpler approach - add checkbox at the start of the card content
# Find the Row with the status badge and add checkbox before it
checkbox_pattern = r'(child: Column\(\s+crossAxisAlignment: CrossAxisAlignment\.start,\s+children: \[\s+// Header Row\s+Row\(\s+children: \[)'

checkbox_replacement = r'''child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Selection checkbox
                    if (_isSelectionMode)
                      Checkbox(
                        value: _selectedQuotationIds.contains(quotation['id']),
                        onChanged: (bool? value) {
                          _toggleQuotationSelection(quotation['id']);
                        },
                        activeColor: const Color(0xFF3B82F6),
                      ),'''

content = re.sub(checkbox_pattern, checkbox_replacement, content, count=1, flags=re.MULTILINE)

# Write the modified content back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Selection UI added successfully!")
print("Added:")
print("1. Select/Cancel buttons in header")
print("2. Delete Selected button (appears when items are selected)")
print("3. Checkboxes on quotation cards in selection mode")
