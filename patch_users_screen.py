import os

file_path = r"c:\Antigravity\Contracto 4\Contracto\admin+app\Najmi-Admin-main\lib\features\users\users_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's define the target pattern we want to find, using flexible line endings
target = """                                            Text(
                                              '($customerId)',
                                              style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12),
                                            ),"""

# Normalize target to use the same line endings as the file (detect \r\n or \n)
line_ending = "\r\n" if "\r\n" in content else "\n"
target_normalized = target.replace("\n", line_ending)

replacement = """                                            if (isBusiness && user.gstNumber != null && user.gstNumber!.isNotEmpty)
                                              Text(
                                                'GST: ${user.gstNumber}',
                                                style: const TextStyle(
                                                    color: Color(0xFF4F46E5),
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            Text(
                                              '($customerId)',
                                              style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12),
                                            ),""".replace("\n", line_ending)

if target_normalized in content:
    new_content = content.replace(target_normalized, replacement)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("SUCCESS: users_screen.dart patched successfully!")
else:
    # Try with another indentation/format just in case
    print("ERROR: Target pattern not found in users_screen.dart")
