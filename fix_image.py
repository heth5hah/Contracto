file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quote_request_cart_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace imageUrl with photos
content = content.replace('item.product.imageUrl', 'item.product.photos.first')
content = content.replace('item.product.imageUrl!.isNotEmpty', 'item.product.photos.isNotEmpty')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Fixed image property!")
