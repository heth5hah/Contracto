import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/address/data/models/address_model.dart';

class AddressService {
  Future<List<AddressModel>> getAddresses() async {
    print('[AddressService] getAddresses() called');
    final currentUser = SupabaseService.instance.currentUser;
    if (currentUser == null) {
      print('[AddressService] No current user');
      return [];
    }

    print('[AddressService] Fetching addresses for user: ${currentUser.id}');
    final response = await SupabaseService.client
        .from('addresses')
        .select()
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false);

    print('[AddressService] Response: $response');
    print('[AddressService] Response type: ${response.runtimeType}');
    
    final addresses = (response as List)
        .map((json) => AddressModel.fromJson(json))
        .toList();
    
    print('[AddressService] Parsed ${addresses.length} addresses');
    return addresses;
  }

  Future<AddressModel> addAddress(AddressModel address) async {
    print('[AddressService] addAddress() called');
    final currentUser = SupabaseService.instance.currentUser;
    if (currentUser == null) {
      print('[AddressService] No current user for addAddress');
      throw Exception('User not authenticated');
    }

    // CRITICAL FIX: Ensure user profile exists in users table
    await _ensureUserProfileExists(currentUser.id, currentUser.email ?? '');

    final addressData = {
      'user_id': currentUser.id,
      'address': address.fullAddress,
      'label': address.label,
      'street_address': address.streetAddress,
      'landmark': address.landmark,
      'city': address.city,
      'state': address.state,
      'pincode': address.pincode,
      'is_default': address.isDefault,
    };

    print('[AddressService] Inserting address data: $addressData');

    final response = await SupabaseService.client
        .from('addresses')
        .insert(addressData)
        .select()
        .single();

    print('[AddressService] Insert response: $response');
    
    final savedAddress = AddressModel.fromJson(response);
    print('[AddressService] Address saved with ID: ${savedAddress.id}');
    
    return savedAddress;
  }

  /// Ensures that a user profile exists in the public.users table
  /// This fixes the foreign key constraint error when adding addresses
  Future<void> _ensureUserProfileExists(String userId, String email) async {
    try {
      print('[AddressService] ========================================');
      print('[AddressService] Checking if user profile exists for: $userId');
      print('[AddressService] Email: $email');
      
      // Get user metadata from auth
      final authUser = SupabaseService.instance.currentUser;
      final metadata = authUser?.userMetadata ?? {};
      
      // 1. Try to use the robust RPC function (Best, Bypasses RLS)
      try {
        print('[AddressService] ⚡ Attempting RPC handle_user_profile...');
        final rpcData = {
          'p_user_id': userId,
          'p_email': email,
          'p_name': metadata['name'] ?? metadata['full_name'] ?? email.split('@')[0],
          'p_mobile': metadata['phone'] ?? metadata['mobile'] ?? '',
          'p_user_type': metadata['user_type'] ?? 'individual',
          'p_company_name': metadata['company_name'],
          'p_gst_number': metadata['gst_number'],
          'p_pan_number': metadata['pan_number'],
        };
        
        await SupabaseService.client.rpc('handle_user_profile', params: rpcData);
        print('[AddressService] ✅ User profile confirmed via RPC!');
        print('[AddressService] ========================================');
        return; // Success!
      } catch (rpcError) {
        print('[AddressService] ⚠️ RPC call failed (Function might not exist yet).');
        print('[AddressService] Error: $rpcError');
        print('[AddressService] Falling back to client-side logic...');
      }

      // 2. Client-side Fallback (Subject to RLS)
      // Check if user exists in users table by ID
      final existing = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        print('[AddressService] ❌ User profile NOT found by ID!');
        
        // Check if profile exists by EMAIL (orphaned profile case)
        // Note: This might return null if RLS prevents seeing other users
        final existingByEmail = await SupabaseService.client
            .from('users')
            .select('id')
            .eq('email', email)
            .maybeSingle();
            
        if (existingByEmail != null) {
          print('[AddressService] ⚠️ Found existing profile with same email but different ID!');
          print('[AddressService] 🔄 Attempting to update profile ID...');
          
          try {
            await SupabaseService.client
                .from('users')
                .update({'id': userId, 'status': 'active'})
                .eq('email', email);
            print('[AddressService] ✅ Profile recovered and ID updated!');
            return;
          } catch (e) {
             print('[AddressService] ❌ Failed to update profile ID: $e');
             throw Exception('Account conflict: Email exists but ID update failed. Please run setup_user_helper.sql');
          }
        }

        print('[AddressService] 🔨 Attempting to create user profile...');
        
        final userData = {
          'id': userId,
          'email': email,
          'name': metadata['name'] ?? metadata['full_name'] ?? email.split('@')[0],
          'mobile': metadata['phone'] ?? metadata['mobile'] ?? '',
          'user_type': metadata['user_type'] ?? 'individual',
          'company_name': metadata['company_name'],
          'is_gst_registered': metadata['is_gst_registered'] ?? false,
          'gst_number': metadata['gst_number'],
          'pan_number': metadata['pan_number'],
          'role': 'customer',
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        };
        
        try {
          await SupabaseService.client.from('users').insert(userData).select().single();
          print('[AddressService] ✅ User profile created successfully!');
        } catch (insertError) {
          print('[AddressService] ❌ FAILED to create user profile!');
          
          final errorStr = insertError.toString();
          if (errorStr.contains('23505') || errorStr.contains('duplicate key')) {
             print('[AddressService] 🛑 DUPLICATE KEY ERROR: The user exists but RLS hid it!');
             print('[AddressService] PLEASE RUN THE SQL SCRIPT: setup_user_helper.sql');
             throw Exception('Database Error: Duplicate Profile. Please ask Admin to run repair script.');
          }
          rethrow;
        }
      } else {
        print('[AddressService] ✅ User profile already exists');
      }
      print('[AddressService] ========================================');
    } catch (e, stackTrace) {
      print('[AddressService] ❌❌❌ CRITICAL ERROR in _ensureUserProfileExists ❌❌❌');
      print('[AddressService] Error: $e');
      print('[AddressService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<AddressModel> updateAddress(AddressModel address) async {
    final currentUser = SupabaseService.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final addressData = {
      'user_id': currentUser.id,
      'address': address.fullAddress,
      'label': address.label,
      'street_address': address.streetAddress,
      'landmark': address.landmark,
      'city': address.city,
      'state': address.state,
      'pincode': address.pincode,
      'is_default': address.isDefault,
    };

    final response = await SupabaseService.client
        .from('addresses')
        .update(addressData)
        .eq('id', address.id)
        .select()
        .single();

    return AddressModel.fromJson(response);
  }

  Future<void> deleteAddress(String id) async {
    await SupabaseService.client.from('addresses').delete().eq('id', id);
  }

  Future<void> setDefaultAddress(String addressId) async {
    final currentUser = SupabaseService.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    // First, unset all other addresses as default for this user
    await SupabaseService.client
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', currentUser.id);

    // Then set the selected address as default
    await SupabaseService.client
        .from('addresses')
        .update({'is_default': true})
        .eq('id', addressId)
        .eq('user_id', currentUser.id);
  }

  Future<AddressModel?> getDefaultAddress() async {
    final currentUser = SupabaseService.instance.currentUser;
    if (currentUser == null) return null;

    final response = await SupabaseService.client
        .from('addresses')
        .select()
        .eq('user_id', currentUser.id)
        .eq('is_default', true)
        .maybeSingle();

    return response != null ? AddressModel.fromJson(response) : null;
  }
}
