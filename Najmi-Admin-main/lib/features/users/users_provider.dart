import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'user_model.dart';
import '../featured/featured_model.dart';

final usersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    print('Fetching users from database...');
    
    // First, check if we're authenticated
    final currentUser = supabase.auth.currentUser;
    print('Current user: ${currentUser?.id}');
    
    if (currentUser == null) {
      print('No authenticated user found');
      throw Exception('Not authenticated. Please log in as admin.');
    }
    
    // Check if current user is admin (but don't block - let RLS handle it)
    String? userRole;
    try {
      final currentUserData = await supabase
          .from('users')
          .select('role, email, name')
          .eq('id', currentUser.id)
          .maybeSingle();
      
      userRole = currentUserData?['role']?.toString();
      final userRoleLower = userRole?.toLowerCase();
      print('Current user info:');
      print('  - ID: ${currentUser.id}');
      print('  - Email: ${currentUserData?['email']}');
      print('  - Name: ${currentUserData?['name']}');
      print('  - Role (raw): $userRole');
      print('  - Role (lowercase): $userRoleLower');
      
      // Check if role is admin (case-insensitive)
      if (userRoleLower != 'admin' && userRole != 'admin') {
        print('⚠️ WARNING: Current user role is "$userRole" (not "admin")');
        print('💡 Attempting to fetch users anyway - RLS will determine access');
        print('💡 If access is denied, run this SQL in Supabase:');
        print('   UPDATE users SET role = \'admin\' WHERE id = \'${currentUser.id}\';');
        print('   Or run: force_admin_role.sql');
        // Don't throw - let the actual query fail if RLS blocks it
      } else {
        print('✅ User is confirmed as admin (role: $userRole)');
      }
    } catch (e) {
      print('⚠️ Could not check user role: $e');
      print('💡 Continuing anyway - will attempt to fetch users');
      // Continue - the actual query will show the real error
    }
    
    // Fetch all users
    print('Attempting to fetch all users...');
    
    try {
      final response = await supabase
          .from('users')
          .select('*')
          .order('created_at', ascending: false);
      
      print('✅ Query executed successfully!');
      print('Response type: ${response.runtimeType}');
      print('Response length: ${response.length}');
      
      if (response == null) {
        print('❌ Response is null - possible RLS policy blocking access');
        throw Exception('Failed to fetch users. Response is null. Check RLS policies and ensure you are logged in as admin.');
      }
      
      // Check if response is a List
      if (response is! List) {
        print('⚠️ Response is not a List: ${response.runtimeType}');
        print('Response value: $response');
        throw Exception('Unexpected response type: ${response.runtimeType}');
      }
      
      final responseList = response as List;
      print('Response is a List with ${responseList.length} items');
      
      if (responseList.isEmpty) {
        print('⚠️ No users found in database (empty list)');
        print('💡 This could mean:');
        print('   1. There are no users in the database');
        print('   2. RLS policies are blocking access (most likely)');
        print('   3. Your user is not set as admin');
        print('');
        print('🔍 DIAGNOSTIC STEPS:');
        print('   1. Run in Supabase SQL Editor:');
        print('      SELECT COUNT(*) FROM users;');
        print('      (If this shows > 0, users exist but RLS is blocking)');
        print('');
        print('   2. Check if you are admin:');
        print('      SELECT id, email, role FROM users WHERE id = auth.uid();');
        print('      (Should show role = \'admin\')');
        print('');
        print('   3. Test the is_admin function:');
        print('      SELECT public.is_admin(auth.uid());');
        print('      (Should return true)');
        print('');
        print('   4. If is_admin returns false, run:');
        print('      UPDATE users SET role = \'admin\' WHERE id = auth.uid();');
        print('');
        print('   5. TEMPORARY TEST (removes security - only for testing):');
        print('      Run temporarily_disable_users_rls.sql');
        print('      If users appear, the issue is RLS policies');
        print('      Then re-enable RLS and fix policies');
        
        // Try a test query to confirm RLS blocking
        try {
          final testResponse = await supabase
              .from('users')
              .select('id')
              .limit(1);
          print('');
          print('📊 Test query result: ${testResponse.length} rows');
          if (testResponse.isNotEmpty) {
            print('   First user ID: ${testResponse.first['id']}');
          }
        } catch (testError) {
          print('');
          print('❌ Test query also failed: $testError');
          print('   → This confirms RLS is blocking access');
        }
        print('');
        print('📖 See USERS_TROUBLESHOOTING.md for complete guide');
        
        return [];
      }
      
      // Log first user to see structure
      if (responseList.isNotEmpty) {
        print('First user data: ${responseList.first}');
        print('User Keys: ${responseList.first.keys.toList()}');
      }
      
      // Pre-fetch all business credit accounts to avoid N+1 queries
      final Map<String, Map<String, dynamic>> creditAccountsMap = {};
      try {
        final creditAccountsRes = await supabase
            .from('business_credit_accounts')
            .select('user_id, credit_limit, available_credit, used_credit, kyc_status, status');
        if (creditAccountsRes != null && creditAccountsRes is List) {
          for (var account in creditAccountsRes) {
            final userId = account['user_id']?.toString();
            if (userId != null) {
              creditAccountsMap[userId] = Map<String, dynamic>.from(account);
            }
          }
        }
      } catch (e) {
        print('Error pre-fetching business credit accounts: $e');
      }

      // Pre-fetch all orders to calculate counts and total spent
      final Map<String, List<double>> userOrdersMap = {};
      try {
        final ordersRes = await supabase
            .from('orders')
            .select('user_id, total_amount');
        if (ordersRes != null && ordersRes is List) {
          for (var order in ordersRes) {
            final userId = order['user_id']?.toString();
            final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
            if (userId != null) {
              userOrdersMap.putIfAbsent(userId, () => []).add(amount);
            }
          }
        }
      } catch (e) {
        print('Error pre-fetching orders: $e');
      }

      final users = <AdminUser>[];
      
      for (var userJson in responseList) {
        try {
          final userId = userJson['id']?.toString();
          if (userId == null) continue;
          
          final userOrders = userOrdersMap[userId] ?? [];
          final ordersCount = userOrders.length;
          final totalSpent = userOrders.fold<double>(0.0, (sum, amt) => sum + amt);
          
          final creditData = creditAccountsMap[userId];
          
          // Create user with calculated values and credit data
          final user = AdminUser.fromJson({
            ...userJson,
            'orders_count': ordersCount,
            'total_spent': totalSpent,
            if (creditData != null) 'business_credit_accounts': creditData,
          });
          
          users.add(user);
          print('✅ Successfully parsed user: ${user.name} (${user.email})');
        } catch (e, stackTrace) {
          print('❌ Error parsing user: $e');
          print('User JSON: $userJson');
          print('Stack trace: $stackTrace');
          // Skip this user and continue
          continue;
        }
      }
      
      print('✅ Successfully parsed ${users.length} out of ${responseList.length} users');
      return users;
      
    } catch (e, stackTrace) {
      print('❌ Error fetching users: $e');
      print('Stack trace: $stackTrace');
      
      // Provide helpful error message
      if (e.toString().contains('permission denied') || 
          e.toString().contains('RLS') ||
          e.toString().contains('policy')) {
        throw Exception('Access denied by RLS policies. Make sure:\n'
            '1. Your user has role = \'admin\' in the users table\n'
            '2. Run force_admin_role.sql in Supabase\n'
            '3. Log out and log back in after updating role');
      }
      
      rethrow;
    }
  } catch (e, stackTrace) {
    print('❌ Fatal error in usersProvider: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
});

final deleteUserProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    print('Deleting user: $userId');
    await supabase.from('users').delete().eq('id', userId);
    ref.invalidate(usersProvider);
    return true;
  } catch (e) {
    print('Error deleting user: $e');
    return false;
  }
});
