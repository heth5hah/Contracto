import 'package:flutter/foundation.dart';
import 'package:contracto_app/core/config/app_config.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String testEmail = 'test@contracto.com';
  static const String testPassword = 'password123';

  /// Sign in with email and password
  /// Returns user data if successful, null otherwise
  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    // Let exceptions propagate so the UI can handle specific error types
    // (e.g., email_not_confirmed, invalid_credentials)
    final response = await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Get user data from our custom users table
      var userData = await _getUserByEmail(email);
      
      String errorDetails = '';
      if (userData == null) {
        final metadata = response.user!.userMetadata ?? {};
        final name = metadata['name'] ?? email.split('@')[0];
        final mobile = metadata['mobile'] ?? '';
        final userTypeStr = metadata['user_type'] ?? 'individual';
        final companyName = metadata['company_name'];
        final gstNumber = metadata['gst_number'];
        final pan = metadata['pan_number'];

        try {
          print('First Login: Creating/Verifying user profile via RPC...');
          final rpcData = {
            'p_user_id': response.user!.id,
            'p_email': email,
            'p_name': name,
            'p_mobile': mobile,
            'p_user_type': userTypeStr,
            'p_company_name': companyName,
            'p_gst_number': gstNumber,
            'p_pan_number': pan,
          };
          
          await SupabaseService.client.rpc('handle_user_profile', params: rpcData);
          print('User profile secured via RPC');
        } catch (e) {
          print('RPC Error: $e');
          errorDetails = e.toString();
          // Last resort manual insert
          try {
             print('Attempting manual insert...');
             final manualData = {
              'id': response.user!.id,
              'name': name,
              'email': email,
              'mobile': mobile,
              'pan_number': pan,
              'gst_number': gstNumber,
              'user_type': userTypeStr,
              'company_name': companyName,
              'status': 'active',
              'role': 'customer',
              'created_at': DateTime.now().toIso8601String(),
            };
            await SupabaseService.client.from('users').insert(manualData);
            errorDetails = ''; // Reset if manual insert works
          } catch(manualError) {
             print('Manual insert error: $manualError');
             errorDetails = manualError.toString();
          }
        }

        // HOTFIX: Override any auto-activation from the RPC/Database trigger
        if (userTypeStr == 'company' || userTypeStr == 'business') {
          print('Downgrading new company credit account to pending state...');
          try {
            await SupabaseService.client
                .from('business_credit_accounts')
                .update({
                  'status': 'pending',
                  'credit_limit': 0,
                  'available_credit': 0,
                })
                .eq('user_id', response.user!.id)
                .eq('used_credit', 0); // extra safety to only affect brand new accounts
          } catch (e) {
            print('Error downgrading new credit account: $e');
          }
        }
        // Re-fetch now that they are created
        userData = await _getUserByEmail(email);
      }

      if (userData != null) {
        return userData;
      } else {
        // User exists in auth but could not be created/found in our users table
        await signOut();
        String diagnosticMsg = 'Account record could not be created.';
        if (errorDetails.isNotEmpty) {
          if (errorDetails.contains('23505')) {
             diagnosticMsg = 'Account creation failed: A user with this Mobile, GST, or PAN already exists.';
          } else {
             diagnosticMsg = 'Database Error: $errorDetails';
          }
        }
        throw Exception(diagnosticMsg);
      }
    }
    return null;
  }

  /// Register new user with email and password
  /// Returns user data if successful, null otherwise
  Future<UserModel?> registerWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String mobile,
    String? pan, // Required for company, optional for individual
    String? gstNumber, // Required for company, optional for individual
    UserType userType = UserType.individual,
    String? companyName, // Required for company users
  }) async {
    try {
      // IMPORTANT: Check if email already exists BEFORE calling signUp
      // Supabase allows duplicate signups and just sends another verification email
      // We need to prevent this and show proper error
      final emailExists = await isEmailRegistered(email);
      if (emailExists) {
        throw Exception('User already registered with this email');
      }
      
      // First, sign up the user in Supabase Auth
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'mobile': mobile,
          'pan_number': pan,
          'gst_number': gstNumber,
          'user_type': userType == UserType.company ? 'company' : 'individual',
          'company_name': companyName,
        },
        emailRedirectTo: 'https://contractobuild.com/',
      );

      if (response.user != null) {
        print('User created successfully in Supabase Auth: ${response.user!.id}');

        // IMMEDIATELY insert into public.users — do NOT rely solely on the DB trigger
        // The trigger can silently fail due to unique constraint conflicts with orphaned records
        final userTypeStr = userType == UserType.company ? 'company' : 'individual';
        bool insertedSuccessfully = false;

        // Attempt 1: Use the RPC (handles upsert safely)
        try {
          print('[Registration] Attempting RPC handle_user_profile...');
          await SupabaseService.client.rpc('handle_user_profile', params: {
            'p_user_id': response.user!.id,
            'p_email': email,
            'p_name': name,
            'p_mobile': mobile,
            'p_user_type': userTypeStr,
            'p_company_name': companyName,
            'p_gst_number': gstNumber,
            'p_pan_number': pan,
          });
          print('[Registration] RPC handle_user_profile succeeded');
          insertedSuccessfully = true;
        } catch (rpcError) {
          print('[Registration] RPC failed: $rpcError');
        }

        // Attempt 2: Direct insert if RPC failed
        if (!insertedSuccessfully) {
          try {
            print('[Registration] Attempting direct insert into public.users...');
            await SupabaseService.client.from('users').upsert({
              'id': response.user!.id,
              'name': name,
              'email': email,
              'mobile': mobile,
              'pan_number': pan,
              'gst_number': gstNumber,
              'user_type': userTypeStr,
              'company_name': companyName,
              'is_gst_registered': gstNumber != null && gstNumber.isNotEmpty,
              'status': 'active',
              'role': 'customer',
              'credit_limit': 0,
              'created_at': DateTime.now().toIso8601String(),
            }, onConflict: 'id');
            print('[Registration] Direct insert succeeded');
            insertedSuccessfully = true;
          } catch (insertError) {
            print('[Registration] Direct insert failed: $insertError');
          }
        }

        // Verify the user actually exists in public.users
        final verifyUser = await _getUserByEmail(email);
        
        // HOTFIX: Override any auto-activation from the RPC/Database trigger
        if (userType == UserType.company) {
          print('[Registration] Downgrading new company credit account to pending state...');
          try {
            await SupabaseService.client
                .from('business_credit_accounts')
                .update({
                  'status': 'pending',
                  'credit_limit': 0,
                  'available_credit': 0,
                })
                .eq('user_id', response.user!.id)
                .eq('used_credit', 0); // extra safety to only affect brand new accounts
            print('[Registration] Successfully downgraded credit account to pending');
          } catch (e) {
            print('[Registration] Error downgrading new credit account: $e');
          }
        }

        if (verifyUser != null) {
          print('[Registration] VERIFIED: User exists in public.users table');
          return verifyUser;
        }

        // If we still can't find them, return a local model 
        // (the trigger or first-login flow will catch up)
        print('[Registration] WARNING: Could not verify user in public.users, returning local model');
        return UserModel(
          id: response.user!.id,
          name: name,
          email: email,
          mobile: mobile,
          pan: pan,
          gstNumber: gstNumber,
          userType: userType,
          companyName: companyName,
          isGstRegistered: gstNumber != null && gstNumber.isNotEmpty,
          role: 'customer',
          creditLimit: 0.0,
          status: 'active',
          createdAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Error registering user: $e');
      rethrow; // Re-throw to see the actual error
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      // 1. Try using the secure RPC (bypasses RLS limits for anon users)
      try {
        final rpcResult = await SupabaseService.client.rpc(
          'check_email_exists', 
          params: {'p_email': email}
        );
        
        // Handle boolean return directly
        if (rpcResult == true) {
          print('Email found via RPC check');
          return true;
        }
      } catch (e) {
        // If function doesn't exist or fails, we fall back to standard checks
        print('RPC check_email_exists failed (using fallback): $e');
      }

      // 2. Fallback: Check our users table directly
      // Note: This might return null if RLS prevents anon reads
      final userTableCheck = await _getUserByEmail(email);
      if (userTableCheck != null) {
        return true;
      }
      
      // 3. Last Line of Defense: Check generic query
      try {
        final authCheck = await SupabaseService.client
            .from('users')
            .select('email')
            .eq('email', email.toLowerCase())
            .maybeSingle();
        
        if (authCheck != null) {
          return true;
        }
      } catch (e) {
        print('Additional email check error: $e');
      }
      
      return false;
    } catch (e) {
      print('Error checking email registration: $e');
      return false;
    }
  }

  /// Check if PAN number is already registered
  Future<bool> isPanRegistered(String pan) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('pan', pan)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking PAN registration: $e');
      return false;
    }
  }

  /// Check if GST number is already registered
  Future<bool> isGstRegistered(String gst) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('gst_number', gst)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking GST registration: $e');
      return false;
    }
  }

  /// Check if mobile number is already registered
  Future<bool> isMobileRegistered(String mobile) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('mobile', mobile)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking mobile registration: $e');
      return false;
    }
  }

  /// Initialize test user (for development)
  Future<void> initializeTestUser() async {
    try {
      // Check if test user already exists
      final existingUser = await _getUserByEmail(testEmail);
      if (existingUser != null) {
        print('Test user already exists');
        return;
      }

      // Create test user in Supabase Auth
      final response = await SupabaseService.client.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'name': 'Test User',
          'mobile': '9999999999',
          'pan': 'ABCDE1234F',
        },
      );

      if (response.user != null) {
        print('Test user created successfully in auth');

        // Also create user in users table
        try {
          await SupabaseService.client.from('users').insert({
            'id': response.user!.id,
            'name': 'Test User',
            'email': testEmail,
            'mobile': '9999999999',
            'pan': 'ABCDE1234F',
            'role': 'customer',
            'status': 'active',
          });
          print('Test user created successfully in users table');
        } catch (e) {
          print('Error creating user in users table: $e');
        }
      }
    } catch (e) {
      print('Error initializing test user: $e');
    }
  }

  /// Get user by email from database
  Future<UserModel?> _getUserByEmail(String email) async {
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

  /// Get current user from Supabase Auth
  User? get currentUser => SupabaseService.client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      final String redirectTo = kDebugMode
          ? 'http://localhost:8000/auth/reset-password'
          : '${AppConfig.websiteUrl}/auth/reset-password';

      await SupabaseService.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  /// Resend confirmation email
  Future<void> resendConfirmationEmail(String email) async {
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'https://contractobuild.com/',
      );
    } catch (e) {
      print('Error resending confirmation email: $e');
      rethrow;
    }
  }

  /// Update user profile
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
}
