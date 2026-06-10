#!/usr/bin/env python3
"""Script to add checkbox to quotation cards"""

import re

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add checkbox at the start of the card's Row (Header Row)
# Find the pattern and add checkbox
pattern = r'(children: \[\s+// Header Row\s+Row\(\s+children: \[)'
replacement = r'''children: [
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

content = re.sub(pattern, replacement, content, count=1)

# Also update the GestureDetector's onTap to handle selection mode
gesture_pattern = r'return GestureDetector\(\s+onTap: \(\) => _showQuoteDetails\(quotation\),'
gesture_replacement = r'''return GestureDetector(
      onTap: _isSelectionMode 
          ? () => _toggleQuotationSelection(quotation['id'])
          : () => _showQuoteDetails(quotation),'''

content = re.sub(gesture_pattern, gesture_replacement, content, count=1)

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Checkbox added to quotation cards!")
print("✅ Card tap behavior updated for selection mode!")
