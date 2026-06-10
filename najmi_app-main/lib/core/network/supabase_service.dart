import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:contracto_app/features/auth/presentation/screens/welcome_screen.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static bool hasPendingRecovery = false;

  static late final SupabaseService instance;
  static late final GoTrueClient auth;
  static late final SupabaseClient client;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
      );
      final supabase = Supabase.instance.client;
      auth = supabase.auth;
      client = supabase;
      instance = SupabaseService();

      // Listen to auth events immediately to catch early recovery events on cold start
      auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          debugPrint('🔑 [SupabaseService] Early recovery event detected!');
          hasPendingRecovery = true;
        }
      });

      // Clear any invalid sessions on startup
      await _clearInvalidSession();
    } catch (e) {
      print('Error initializing Supabase: $e');
      // Re-initialize without auto refresh if there's an error
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: false,
        ),
      );
      final supabase = Supabase.instance.client;
      auth = supabase.auth;
      client = supabase;
      instance = SupabaseService();

      // Listen to auth events immediately to catch early recovery events on cold start
      auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          debugPrint('🔑 [SupabaseService] Early recovery event detected!');
          hasPendingRecovery = true;
        }
      });
    }
  }

  // Clear invalid sessions that might cause refresh token errors
  static Future<void> _clearInvalidSession() async {
    try {
      final session = auth.currentSession;
      if (session != null) {
        // Check if session is expired or invalid
        try {
          final now = DateTime.now().millisecondsSinceEpoch / 1000;
          if (session.expiresAt != null && session.expiresAt! < now) {
            // Session is expired, sign out to clear it
            await auth.signOut();
            return;
          }
          
          // Try to access token to validate it's properly formatted
          final token = session.accessToken;
          if (token.isEmpty) {
            await auth.signOut();
            return;
          }
        } catch (e) {
          // JWT format errors or token validation errors
          print('JWT token validation error: $e');
          await auth.signOut();
          return;
        }
      }
    } catch (e) {
      print('Error clearing invalid session: $e');
      // If there's any error with the session (including JWT format errors), sign out to clear it
      try {
        await auth.signOut();
      } catch (_) {
        // Ignore sign out errors
      }
    }
  }

  // Auth Methods
  Future<void> signInWithOTP({
    required String phone,
  }) async {
    await auth.signInWithOtp(
      phone: phone,
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: 'https://contractobuild.com/',
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  // User Session Management
  User? get currentUser {
    try {
      return auth.currentUser;
    } catch (e) {
      // Handle JWT format errors gracefully
      if (e.toString().contains('JWT') || 
          e.toString().contains('FormatException') ||
          e.toString().contains('Invalid value') ||
          e.toString().contains('exp')) {
        print('JWT error accessing currentUser, clearing session: $e');
        // Sign out asynchronously to clear invalid token
        auth.signOut().catchError((_) {});
        return null;
      }
      rethrow;
    }
  }

  bool get isAuthenticated {
    try {
      return auth.currentUser != null;
    } catch (e) {
      // Handle JWT format errors gracefully
      if (e.toString().contains('JWT') || 
          e.toString().contains('FormatException') ||
          e.toString().contains('Invalid value') ||
          e.toString().contains('exp')) {
        print('JWT error checking authentication, clearing session: $e');
        // Sign out asynchronously to clear invalid token
        auth.signOut().catchError((_) {});
        return false;
      }
      return false;
    }
  }

  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  // Enhanced session management for persistent auth
  Future<bool> hasValidSession() async {
    try {
      final session = auth.currentSession;
      if (session == null) return false;

      // Check if session is still valid
      try {
        final user = auth.currentUser;
        if (user == null) return false;
        
        // Validate token format by checking expiration
        final now = DateTime.now().millisecondsSinceEpoch / 1000;
        if (session.expiresAt != null && session.expiresAt! < now) {
          return false;
        }
        
        return true;
      } catch (e) {
        // JWT format or token validation errors - clear session
        if (e.toString().contains('JWT') || 
            e.toString().contains('FormatException') ||
            e.toString().contains('Invalid value') ||
            e.toString().contains('exp')) {
          print('JWT token error detected, clearing session: $e');
          try {
            await auth.signOut();
          } catch (_) {
            // Ignore sign out errors
          }
        }
        return false;
      }
    } catch (e) {
      print('Error checking session validity: $e');
      // If it's a JWT format error, try to clear the session
      if (e.toString().contains('JWT') || 
          e.toString().contains('FormatException') ||
          e.toString().contains('Invalid value') ||
          e.toString().contains('exp')) {
        try {
          await auth.signOut();
        } catch (_) {
          // Ignore sign out errors
        }
      }
      return false;
    }
  }

  Future<void> refreshSession() async {
    try {
      await auth.refreshSession();
    } catch (e) {
      print('Error refreshing session: $e');
      // If refresh token is already used, invalid, or JWT format error, sign out
      if (e.toString().contains('refresh_token_already_used') ||
          e.toString().contains('Invalid Refresh Token') ||
          e.toString().contains('JWT') ||
          e.toString().contains('FormatException') ||
          e.toString().contains('Invalid value') ||
          e.toString().contains('exp')) {
        print('Token invalid or corrupted, signing out...');
        try {
          await auth.signOut();
        } catch (_) {
          // Ignore sign out errors
        }
      }
      rethrow;
    }
  }

  // Check and maintain session persistence
  Future<bool> maintainSession() async {
    try {
      if (await hasValidSession()) {
        return true;
      }

      // Try to refresh if session exists but might be expired
      if (auth.currentSession != null) {
        await refreshSession();
        return await hasValidSession();
      }

      return false;
    } catch (e) {
      print('Error maintaining session: $e');
      return false;
    }
  }

  // Database Methods
  Future<List<Map<String, dynamic>>> getProducts() async {
    final response = await client
        .from('products')
        .select()
        .order('created_at', ascending: false);
    return response;
  }

  Future<List<Map<String, dynamic>>> getQuotations(String userId) async {
    final response = await client
        .from('quotations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response;
  }

  Future<void> createQuotation(Map<String, dynamic> quotation) async {
    await client.from('quotations').insert(quotation);
  }

  Future<void> updateQuotationStatus({
    required String quotationId,
    required String status,
  }) async {
    await client
        .from('quotations')
        .update({'status': status}).eq('id', quotationId);
  }

  Future<List<Map<String, dynamic>>> getAddresses() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await client
        .from('addresses')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return response;
  }

  Future<void> saveAddress(Map<String, dynamic> address) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Create address data with only fields that exist in the simplified schema
    final addressData = {
      'user_id': user.id,
      'address': address['address'],
      'label': address['label'] ?? 'Home',
    };

    await client.from('addresses').insert(addressData);
  }

  Future<Map<String, dynamic>> getCreditInfo(String userId) async {
    final response =
        await client.from('credit').select().eq('user_id', userId).single();
    return response;
  }

  Future<void> updateNotificationStatus({
    required String notificationId,
    required String status,
  }) async {
    await client
        .from('notifications')
        .update({'status': status}).eq('id', notificationId);
  }

  // User Management Methods
  Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('mobile', phoneNumber)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user by phone: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user by email: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response =
          await client.from('users').select().eq('id', userId).maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user by ID: $e');
      return null;
    }
  }

  Future<bool> isUserRegistered(String phoneNumber) async {
    try {
      final user = await getUserByPhone(phoneNumber);
      return user != null && user['status'] == 'active';
    } catch (e) {
      print('Error checking user registration: $e');
      return false;
    }
  }

  // Handle email verification redirect
  Future<void> handleEmailVerification() async {
    try {
      final session = auth.currentSession;
      if (session != null && session.user.emailConfirmedAt == null) {
        // User needs to verify email
        await auth.resend(
          type: OtpType.signup,
          email: session.user.email!,
          emailRedirectTo: 'https://contractobuild.com/',
        );
      }
    } catch (e) {
      print('Error handling email verification: $e');
    }
  }
  // Check if a user is blocked or deleted
  Future<bool> isUserBlocked(String userId) async {
    try {
      // Direct client call to check status
      final response = await client
          .from('users')
          .select('status')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // User record not found in public.users or RLS preventing read.
        // Returning false to prevent active users from being falsely blocked.
        print('isUserBlocked warning: No record found for $userId. Returning false.');
        return false;
      }

      final status = response['status']?.toString().toLowerCase();
      return status == 'blocked' || status == 'deleted';
    } catch (e) {
      print('Error checking if user is blocked: $e');
      // If we can't check, play it safe or allow? 
      // Usually, if RLS blocks us from reading our own record, it might be because we're deleted.
      return false; 
    }
  }

  /// Global notification for blocked/deleted users
  static void showBlockedNotification(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Restricted'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'This account is deleted or blocked by admin panel.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Centralized error handler to catch RLS blocks
  static Future<void> handleServiceError(BuildContext context, dynamic error) async {
    final errorStr = error.toString().toLowerCase();
    
    // Check for Permission Denied (Postgres code 42501) or RLS failure tokens
    if (errorStr.contains('permission') || 
        errorStr.contains('42501') || 
        errorStr.contains('access denied')) {
      
      final isBlocked = await SupabaseService().isUserBlocked(auth.currentUser?.id ?? '');
      if (isBlocked && context.mounted) {
        showBlockedNotification(context);
        return;
      }
    }
    
    // Fallback: show standard error if not a block
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    }
  }
}
