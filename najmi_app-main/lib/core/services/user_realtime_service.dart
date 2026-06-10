import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../network/supabase_service.dart';

/// Real-time service for mobile app to listen to admin status changes
class UserRealtimeService {
  static final UserRealtimeService _instance = UserRealtimeService._internal();
  factory UserRealtimeService() => _instance;
  UserRealtimeService._internal();

  // Stream controllers
  final _orderStatusUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _quotationStatusUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _returnStatusUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _creditAccountUpdatedController = StreamController<Map<String, dynamic>>.broadcast();

  // Subscription channels
   RealtimeChannel? _ordersChannel;
   RealtimeChannel? _quotesChannel;
   RealtimeChannel? _returnsChannel;
   RealtimeChannel? _securityChannel;
   RealtimeChannel? _creditChannel;

  // Public streams
  Stream<Map<String, dynamic>> get orderStatusUpdatedStream => _orderStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get quotationStatusUpdatedStream => _quotationStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get returnStatusUpdatedStream => _returnStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get creditAccountUpdatedStream => _creditAccountUpdatedController.stream;

  bool _isInitialized = false;
  SupabaseClient? _supabase;
  
  // Audio player for notification sounds
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // App lifecycle state management
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  final List<Map<String, dynamic>> _pendingNotifications = [];
  
  /// Set app lifecycle state (call from main app)
  void setAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    
    // When app comes back to foreground, show pending notifications
    if (state == AppLifecycleState.resumed && _pendingNotifications.isNotEmpty) {
      print('📱 App resumed - showing ${_pendingNotifications.length} pending notifications');
      _showPendingNotifications();
    }
  }
  
  /// Show all pending notifications
  void _showPendingNotifications() {
    for (final notification in _pendingNotifications) {
      _playNotificationSound();
      print('🔔 ${notification['title']}: ${notification['message']}');
    }
    _pendingNotifications.clear();
  }
  
  /// Play notification sound
  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      
      // Play notification sound from URL (works on Android/iOS)
      await _audioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2354/2354-preview.mp3'),
        volume: 1.0,
      );
      
      print('🔊 Notification sound played');
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }
  
  /// Handle notification - queue if app is backgrounded, play if active
  void _handleNotification(String title, String message, String type) {
    if (_appLifecycleState != AppLifecycleState.resumed) {
      // App is in background - queue notification
      print('📥 Queueing notification (app in background): $title');
      _pendingNotifications.add({
        'title': title,
        'message': message,
        'type': type,
        'timestamp': DateTime.now(),
      });
    } else {
      // App is active - play sound immediately
      print('🔔 Playing notification (app active): $title');
      _playNotificationSound();
    }
  }

  /// Initialize the real-time service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('UserRealtimeService already initialized');
      return;
    }

    _supabase = SupabaseService.client;
    final userId = _supabase?.auth.currentUser?.id;

    if (userId == null) {
      print('User not authenticated, cannot initialize real-time service');
      return;
    }

    try {
      print('Initializing UserRealtimeService...');
      
       await _subscribeToOrderUpdates(userId);
       await _subscribeToQuotationUpdates(userId);
       await _subscribeToReturnUpdates(userId);
       await _subscribeToUserSecurityUpdates(userId);
       await _subscribeToCreditUpdates(userId);

      _isInitialized = true;
      print('UserRealtimeService initialized successfully');
    } catch (e) {
      print('Error initializing UserRealtimeService: $e');
    }
  }

  /// Subscribe to order status updates for the current user
  Future<void> _subscribeToOrderUpdates(String userId) async {
    if (_supabase == null) return;

    try {
      _ordersChannel = _supabase!
          .channel('user_orders_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              print('🔄 Order status updated for user!');
              final updatedOrder = payload.newRecord;
              final oldOrder = payload.oldRecord;
              
              bool statusChanged = updatedOrder['order_status'] != oldOrder['order_status'];
              
              // Handle notification only if status changed
              if (statusChanged) {
                _handleNotification(
                  'Order Status Updated',
                  'Your order is now ${updatedOrder['order_status']}',
                  'order',
                );
                print('📦 Order ${updatedOrder['id']} status: ${oldOrder['order_status']} → ${updatedOrder['order_status']}');
              }
              
              // Emit update event for any change (e.g., payment due date updates)
              _orderStatusUpdatedController.add({
                'entity_type': 'order',
                'entity_id': updatedOrder['id'],
                'order_id': updatedOrder['id'],
                'new_status': updatedOrder['order_status'],
                'old_status': oldOrder['order_status'],
                'status_changed': statusChanged,
                'updated_at': updatedOrder['updated_at'],
                'order_data': updatedOrder,
              });
            },
          )
          .subscribe();

      print('Subscribed to user order status updates');
    } catch (e) {
      print('Error subscribing to order updates: $e');
    }
  }

  /// Subscribe to quotation status updates for the current user
  Future<void> _subscribeToQuotationUpdates(String userId) async {
    if (_supabase == null) return;

    try {
      _quotesChannel = _supabase!
          .channel('user_quotes_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'quote_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              print('🔄 Quotation status updated for user!');
              final updatedQuote = payload.newRecord;
              final oldQuote = payload.oldRecord;
              
              // Check if status or admin_status changed
              if (updatedQuote['status'] != oldQuote['status'] ||
                  updatedQuote['admin_status'] != oldQuote['admin_status']) {
                // Handle notification based on app state
                _handleNotification(
                  'Quote Response Received',
                  'Your quote request has been ${updatedQuote['admin_status']}',
                  'quotation',
                );
                
                // Emit status update event
                _quotationStatusUpdatedController.add({
                  'entity_type': 'quotation',
                  'entity_id': updatedQuote['id'],
                  'quotation_id': updatedQuote['id'],
                  'new_status': updatedQuote['status'],
                  'old_status': oldQuote['status'],
                  'admin_status': updatedQuote['admin_status'],
                  'updated_at': updatedQuote['updated_at'],
                  'quotation_data': updatedQuote,
                });
                
                print('💬 Quotation ${updatedQuote['id']} status: ${oldQuote['status']} → ${updatedQuote['status']}');
              }
            },
          )
          .subscribe();

      print('Subscribed to user quotation status updates');
    } catch (e) {
      print('Error subscribing to quotation updates: $e');
    }
  }

  /// Subscribe to return status updates for the current user
  Future<void> _subscribeToReturnUpdates(String userId) async {
    if (_supabase == null) return;

    try {
      _returnsChannel = _supabase!
          .channel('user_returns_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'returns',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              print('🔄 Return status updated for user!');
              final updatedReturn = payload.newRecord;
              final oldReturn = payload.oldRecord;
              
              // Check if status changed
              if (updatedReturn['return_status'] != oldReturn['return_status']) {
                // Handle notification based on app state
                _handleNotification(
                  'Return Status Updated',
                  'Your return request is ${updatedReturn['return_status']}',
                  'return',
                );
                
                // Emit status update event
                _returnStatusUpdatedController.add({
                  'entity_type': 'return',
                  'entity_id': updatedReturn['id'],
                  'return_id': updatedReturn['id'],
                  'order_id': updatedReturn['order_id'],
                  'new_status': updatedReturn['return_status'],
                  'old_status': oldReturn['return_status'],
                  'updated_at': updatedReturn['updated_at'],
                  'return_data': updatedReturn,
                });
                
                print('🔄 Return ${updatedReturn['id']} status: ${oldReturn['return_status']} → ${updatedReturn['return_status']}');
              }
            },
          )
          .subscribe();

      print('Subscribed to user return status updates');
    } catch (e) {
       print('Error subscribing to return updates: $e');
     }
   }
 
   /// Subscribe to user record changes (block/delete) for security
   Future<void> _subscribeToUserSecurityUpdates(String userId) async {
     if (_supabase == null) return;
 
     try {
       _securityChannel = _supabase!
           .channel('user_security_updates')
           .onPostgresChanges(
             event: PostgresChangeEvent.all, // Listen for updates and deletes
             schema: 'public',
             table: 'users',
             filter: PostgresChangeFilter(
               type: PostgresChangeFilterType.eq,
               column: 'id',
               value: userId,
             ),
             callback: (payload) async {
               print('🔒 Security update received for user record!');
               
               bool shouldLogout = false;
               
               if (payload.eventType == PostgresChangeEvent.delete) {
                 print('❌ User record deleted! Logging out...');
                 shouldLogout = true;
               } else if (payload.eventType == PostgresChangeEvent.update) {
                 final updatedUser = payload.newRecord;
                 if (updatedUser['status'] == 'blocked') {
                   print('🚫 User blocked! Logging out...');
                   shouldLogout = true;
                 }
               }
               
               if (shouldLogout) {
                 // Force logout immediately
                 await _supabase!.auth.signOut();
                 // We don't need to do more here; AuthGate's StreamBuilder will catch
                 // the auth state change and redirect to WelcomeScreen/Blocked message.
               }
             },
           )
           .subscribe();
 
       print('Subscribed to user security updates');
     } catch (e) {
       print('Error subscribing to security updates: $e');
     }
   }

    /// Subscribe to credit account updates for the current user
    Future<void> _subscribeToCreditUpdates(String userId) async {
      if (_supabase == null) return;
 
      try {
        _creditChannel = _supabase!
            .channel('user_credit_updates')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'business_credit_accounts',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) {
                print('🔄 Credit account updated for user!');
                final updatedAccount = payload.newRecord;
                _creditAccountUpdatedController.add(updatedAccount);
              },
            )
            .subscribe();
 
        print('Subscribed to user credit account updates');
      } catch (e) {
        print('Error subscribing to credit updates: $e');
      }
    }
 
   /// Dispose all subscriptions
  Future<void> dispose() async {
    print('Disposing UserRealtimeService...');

     await _ordersChannel?.unsubscribe();
     await _quotesChannel?.unsubscribe();
     await _returnsChannel?.unsubscribe();
     await _securityChannel?.unsubscribe();
     await _creditChannel?.unsubscribe();

    await _orderStatusUpdatedController.close();
    await _quotationStatusUpdatedController.close();
    await _returnStatusUpdatedController.close();
    await _creditAccountUpdatedController.close();

    _isInitialized = false;
    print('UserRealtimeService disposed');
  }
}
