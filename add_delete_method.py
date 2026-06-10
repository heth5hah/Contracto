#!/usr/bin/env python3
"""Add deleteQuoteRequest method to QuotationService"""

file_path = r'c:\Users\yash3\Downloads\admin+app\najmi_app-main\lib\features\quotations\data\services\quotation_service.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the last closing brace and add the new method
if content.rstrip().endswith('}'):
    content = content.rstrip()[:-1]  # Remove last }
    
delete_method = '''
  // Delete quote request
  Future<void> deleteQuoteRequest(String quoteRequestId) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user ID from users table to ensure proper RLS
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in database');
      }

      // Delete the quote request (RLS will ensure user owns it)
      final response = await SupabaseService.client
          .from('quote_requests')
          .delete()
          .eq('id', quoteRequestId)
          .eq('user_id', userData['id']) // Ensure user owns this quote
          .select();

      print('Delete quote request response: $response');
      
      if (response.isEmpty) {
        throw Exception('Quote request not found or you do not have permission to delete it');
      }
    } catch (e) {
      print('Error deleting quote request: $e');
      rethrow;
    }
  }
}
'''

    content += delete_method

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Added deleteQuoteRequest method to QuotationService!")
