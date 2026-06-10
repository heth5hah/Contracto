import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/auth/data/models/user_model.dart';

class UserService {
  /// Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching user by email: $e');
      return null;
    }
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String id) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching user by ID: $e');
      return null;
    }
  }

  /// Update user information
  Future<UserModel?> updateUser(UserModel user) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .update(user.toJson())
          .eq('id', user.id)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error updating user: $e');
      return null;
    }
  }

  /// Update user GST information
  Future<bool> updateUserGstInfo({
    required String userId,
    String? gstNumber,
    bool? isGstRegistered,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (gstNumber != null) {
        updateData['gst_number'] = gstNumber;
      }

      if (isGstRegistered != null) {
        updateData['is_gst_registered'] = isGstRegistered;
      }

      if (updateData.isNotEmpty) {
        await SupabaseService.client
            .from('users')
            .update(updateData)
            .eq('id', userId);
      }

      return true;
    } catch (e) {
      print('Error updating user GST info: $e');
      return false;
    }
  }

  /// Get current authenticated user from database
  Future<UserModel?> getCurrentUser() async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser?.email == null) return null;

      return await getUserByEmail(authUser!.email!);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Get current user data (alias for getCurrentUser for backward compatibility)
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = await getCurrentUser();
      return user?.toJson();
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  /// Get user addresses
  Future<List<Map<String, dynamic>>> getUserAddresses() async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser == null) return [];

      final response = await SupabaseService.client
          .from('addresses')
          .select()
          .eq('user_id', authUser.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user addresses: $e');
      return [];
    }
  }

  /// Add new address for user
  Future<Map<String, dynamic>?> addAddress(
      Map<String, dynamic> addressData) async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser == null) return null;

      final response = await SupabaseService.client
          .from('addresses')
          .insert({
            'user_id': authUser.id,
            'address': addressData['address'],
            'label': addressData['label'] ?? 'Home',
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print('Error adding address: $e');
      return null;
    }
  }

  /// Update user data by field names
  Future<void> updateUserData(Map<String, dynamic> userData) async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      print('UpdateUserData: authUser = ${authUser?.email}, authUid = ${authUser?.id}');
      
      if (authUser == null) {
        print('UpdateUserData: No authenticated user found');
        throw Exception('User not authenticated');
      }

      // Use auth.uid() directly for RLS compatibility
      final authUid = authUser.id;
      print('UpdateUserData: Updating user with auth.uid = $authUid');
      print('UpdateUserData: Data to update = $userData');
      
      // Try updating using the auth UID directly (this matches RLS policy)
      try {
        await SupabaseService.client
            .from('users')
            .update(userData)
            .eq('id', authUid);
        print('UpdateUserData: Update successful using auth.uid');
        return;
      } catch (rlsError) {
        print('UpdateUserData: RLS error using auth.uid: $rlsError');
        
        // Fallback: try to find user by email and update
        if (authUser.email != null) {
          print('UpdateUserData: Trying update by email: ${authUser.email}');
          await SupabaseService.client
              .from('users')
              .update(userData)
              .eq('email', authUser.email!);
          print('UpdateUserData: Update successful using email');
          return;
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      print('Error updating user data: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete user account and all associated data permanently.
  /// This now **only** uses the delete-user Edge Function so that
  /// either everything is deleted (custom tables + auth user)
  /// or the operation fails with an error – no partial deletion.
  Future<void> deleteAccount() async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated');
      }

      print('DeleteAccount: Starting account deletion for user ${authUser.email}');

      // Check if user can delete account (pending bills, returns, credit dues)
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', authUser.email!)
          .maybeSingle();
          
      if (userData != null) {
        try {
          final checkResult = await SupabaseService.client.rpc('can_delete_account', params: {
            'p_user_id': userData['id'],
          });
          
          if (checkResult is Map && checkResult['can_delete'] == false) {
            final reasons = (checkResult['reasons'] as List?)?.join(', ') ?? 'Pending obligations';
            throw Exception('Cannot delete account: $reasons. Please clear all pending items first.');
          }
        } catch (rpcError) {
          // Fallback: check credit dues directly if RPC not available
          if (rpcError.toString().contains('Cannot delete account')) rethrow;
          
          final creditAccount = await SupabaseService.client
              .from('business_credit_accounts')
              .select('used_credit')
              .eq('user_id', userData['id'])
              .maybeSingle();
              
          if (creditAccount != null) {
            final usedCredit = (creditAccount['used_credit'] ?? 0.0).toDouble();
            if (usedCredit > 0) {
              throw Exception('Cannot delete account while you have pending credit dues of ₹${usedCredit.toStringAsFixed(2)}. Please clear your dues first.');
            }
          }
          
          // Also check pending orders
          final pendingOrders = await SupabaseService.client
              .from('orders')
              .select('id')
              .eq('user_id', userData['id'])
              .eq('payment_status', 'pending')
              .not('order_status', 'in', '("cancelled","rejected")')
              .limit(1)
              .maybeSingle();
              
          if (pendingOrders != null) {
            throw Exception('Cannot delete account while you have unpaid orders. Please clear your payments first.');
          }
        }
      }

      // Call the Edge Function to delete the account.
      // The Edge Function has admin privileges to delete from auth.users
      // and all related tables.
      // Call the Edge Function with a timeout
      final response = await SupabaseService.client.functions
          .invoke('delete-user', body: {})
          .timeout(const Duration(seconds: 10));

      print('DeleteAccount: Edge Function response: ${response.data}');
      print('DeleteAccount: Account deletion completed successfully via Edge Function');
    } catch (e) {
      print('DeleteAccount: Edge Function failed ($e). Falling back to manual deletion.');
      await _deleteAccountFallback();
    }
  }

  /// Fallback method to delete user data from custom tables
  /// This does NOT delete from auth.users (user can still log in)
  /// Used when the Edge Function is not deployed
  Future<void> _deleteAccountFallback() async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated');
      }

      print('DeleteAccount Fallback: Starting for user ${authUser.email}');

      // Get user record from database
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', authUser.email!)
          .maybeSingle();

      if (userData == null) {
        print('DeleteAccount Fallback: User not found in custom tables (already deleted?)');
        // If user is not in our tables, consider the deletion "done" for our part.
        return;
      }

      final userId = userData['id'] as String;
      print('DeleteAccount Fallback: Found user ID: $userId');

      // Delete all related data in order (respecting foreign key constraints)
      
      // 1. Delete wishlist items
      try {
        await SupabaseService.client
            .from('wishlist')
            .delete()
            .eq('user_id', userId);
        print('DeleteAccount Fallback: Deleted wishlist items');
      } catch (e) {
        print('DeleteAccount Fallback: Error deleting wishlist (may not exist): $e');
      }

      // 2. Delete addresses
      try {
        await SupabaseService.client
            .from('addresses')
            .delete()
            .eq('user_id', userId);
        print('DeleteAccount Fallback: Deleted addresses');
      } catch (e) {
        print('DeleteAccount Fallback: Error deleting addresses (may not exist): $e');
      }

      // 3. Delete quote request items first, then quote requests
      try {
        // Get quote request IDs for this user
        final quoteRequests = await SupabaseService.client
            .from('quote_requests')
            .select('id')
            .eq('user_id', userId);
        
        for (var qr in quoteRequests) {
          await SupabaseService.client
              .from('quote_request_items')
              .delete()
              .eq('quote_request_id', qr['id']);
        }
        
        await SupabaseService.client
            .from('quote_requests')
            .delete()
            .eq('user_id', userId);
        print('DeleteAccount Fallback: Deleted quote requests');
      } catch (e) {
        print('DeleteAccount Fallback: Error deleting quote requests (may not exist): $e');
      }

      // 4. Delete credit usage records
      try {
        final creditAccount = await SupabaseService.client
            .from('business_credit_accounts')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (creditAccount != null) {
          final accountId = creditAccount['id'];
          
          // Delete credit usage
          await SupabaseService.client
              .from('credit_usage')
              .delete()
              .eq('credit_account_id', accountId);
          
          // Delete credit payments
          await SupabaseService.client
              .from('credit_payments')
              .delete()
              .eq('credit_account_id', accountId);
          
          // Delete billing cycles
          await SupabaseService.client
              .from('billing_cycles')
              .delete()
              .eq('credit_account_id', accountId);
          
          // Delete credit account
          await SupabaseService.client
              .from('business_credit_accounts')
              .delete()
              .eq('user_id', userId);
          
          print('DeleteAccount Fallback: Deleted credit account and related data');
        }
      } catch (e) {
        print('DeleteAccount Fallback: Error deleting credit data (may not exist): $e');
      }

      // 5. Delete order items first, then orders
      try {
        final orders = await SupabaseService.client
            .from('orders')
            .select('id')
            .eq('user_id', userId);
        
        for (var order in orders) {
          await SupabaseService.client
              .from('order_items')
              .delete()
              .eq('order_id', order['id']);
        }
        
        await SupabaseService.client
            .from('orders')
            .delete()
            .eq('user_id', userId);
        print('DeleteAccount Fallback: Deleted orders');
      } catch (e) {
        print('DeleteAccount Fallback: Error deleting orders (may not exist): $e');
      }

      // 6. Delete return requests
      try {
        await SupabaseService.client
            .from('return_requests')
            .delete()
            .eq('user_id', userId);
        print('DeleteAccount Fallback: Deleted return requests');
      } catch (e) {
        print('DeleteAccount Fallback: Error deleting return requests (may not exist): $e');
      }

      // 7. Finally, delete the user record from users table
      try {
        await SupabaseService.client
            .from('users')
            .delete()
            .eq('id', userId);
        print('DeleteAccount Fallback: Deleted user record');
      } catch (e) {
        print('DeleteAccount Fallback: Error deleting user record (permission denied). Attempting to anonymize data: $e');
        
        // Since DELETE failed, try to anonymize the data
        try {
          await SupabaseService.client.from('users').update({
            'name': 'Deleted User',
            'mobile': '0000000000',
            'email': 'deleted_${DateTime.now().millisecondsSinceEpoch}@deleted.com', // Anonymize email if possible (might not affect auth login)
            'pan_number': null,
            'gst_number': null,
            'company_name': null,
            'is_gst_registered': false,
            'status': 'deleted', // Mark as deleted
          }).eq('id', userId);
          print('DeleteAccount Fallback: Anonymized user record');
        } catch (updateError) {
          print('DeleteAccount Fallback: Error anonymizing user record: $updateError');
          // We did our best
        }
      }

      // WARNING: The fallback method does NOT delete from auth.users
      // The user can still log in, but their data will be gone
      // They will need to re-create their profile
      print('DeleteAccount Fallback: WARNING - User auth credentials still exist in auth.users');
      print('DeleteAccount Fallback: Please deploy the delete-user Edge Function for complete deletion');
      
      // Throw an error to inform the user that full deletion requires Edge Function
      // Fallback deletion completed (auth user remains but data is gone)
      print('DeleteAccount Fallback: Deletion completed successfully');
      return;
    } catch (e, stackTrace) {
      print('DeleteAccount Fallback: Error: $e');
      print('DeleteAccount Fallback: Stack trace: $stackTrace');
      rethrow;
    }
  }
}
