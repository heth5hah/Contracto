import re

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\products\presentation\screens\product_details_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace QuotationsScreen with QuoteRequestCartScreen in the dialog
content = content.replace(
    'builder: (context) => const QuotationsScreen()',
    'builder: (context) => const QuoteRequestCartScreen()'
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Updated navigation to QuoteRequestCartScreen!")
