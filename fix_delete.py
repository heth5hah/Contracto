import re

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\presentation\screens\quotations_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the delete query to include user_id
old_pattern = r'// Delete from database\s+final response = await SupabaseService\.client\s+\.from\(\'quote_requests\'\)\s+\.delete\(\)\s+\.eq\(\'id\', quoteRequestId\)\s+\.select\(\);'

new_code = '''// Get user ID for RLS policy
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in database');
      }

      // Delete from database with user_id for RLS
      final response = await SupabaseService.client
          .from('quote_requests')
          .delete()
          .eq('id', quoteRequestId)
          .eq('user_id', userData['id'])
          .select();'''

content = re.sub(old_pattern, new_code, content, flags=re.MULTILINE | re.DOTALL)

# Also fix the bulk delete
old_bulk = r'// Delete all selected quotations from database\s+for \(final id in idsToDelete\) \{\s+await SupabaseService\.client\s+\.from\(\'quote_requests\'\)\s+\.delete\(\)\s+\.eq\(\'id\', id\);\s+\}'

new_bulk = '''// Get user ID for RLS
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found');
      }

      // Delete all selected quotations from database
      for (final id in idsToDelete) {
        await SupabaseService.client
            .from('quote_requests')
            .delete()
            .eq('id', id)
            .eq('user_id', userData['id']);
      }'''

content = re.sub(old_bulk, new_bulk, content, flags=re.MULTILINE | re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Fixed delete queries to include user_id!")
