import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:contracto_app/features/auth/presentation/screens/update_password_screen.dart';
import 'package:contracto_app/shared/widgets/main_navigation.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  Session? _currentSession;
  bool _isLoading = true;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    
    // Check for pending recovery event from startup (cold start)
    if (SupabaseService.hasPendingRecovery) {
      SupabaseService.hasPendingRecovery = false; // Reset the flag
      debugPrint('🔑 Redirecting to UpdatePasswordScreen from pending startup recovery...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const UpdatePasswordScreen(),
            ),
          );
        }
      });
    }

    // Get initial session and check block status if authenticated
    _currentSession = SupabaseService.auth.currentSession;
    if (_currentSession != null) {
      _checkBlockStatus(_currentSession!.user.id);
    } else {
      _isLoading = false;
    }

    _authSubscription = SupabaseService.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('🔑 Password recovery event detected! Redirecting to UpdatePasswordScreen...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const UpdatePasswordScreen(),
              ),
            );
          }
        });
      }

      _handleAuthStateChange(session);
    });
  }

  void _handleAuthStateChange(Session? session) {
    if (session == null) {
      if (mounted) {
        setState(() {
          _currentSession = null;
          _isBlocked = false;
          _isLoading = false;
        });
      }
    } else {
      // If user changed or we didn't have a session, query the database.
      // Otherwise, just update the session reference without triggering a database check.
      final bool userChanged = _currentSession?.user.id != session.user.id;
      if (userChanged) {
        _checkBlockStatus(session.user.id);
      }
      
      if (mounted) {
        setState(() {
          _currentSession = session;
          if (!userChanged) {
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _checkBlockStatus(String userId) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final isBlocked = await SupabaseService().isUserBlocked(userId);
      if (mounted) {
        setState(() {
          _isBlocked = isBlocked;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking block status in AuthGate: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentSession != null) {
      if (_isBlocked) {
        return const BlockedUserScreen();
      }
      return const MainNavigation();
    } else {
      return const WelcomeScreen();
    }
  }
}

class BlockedUserScreen extends StatelessWidget {
  const BlockedUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red.shade900, Colors.black],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, color: Colors.white, size: 80),
            const SizedBox(height: 32),
            const Text(
              'ACCOUNT RESTRICTED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This account has been deleted or blocked by the admin panel.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () async {
                await SupabaseService().signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
