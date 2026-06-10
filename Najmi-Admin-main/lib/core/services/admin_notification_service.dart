import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
// Conditional import for web
import 'dart:html' as html show Notification;
import 'dart:js' as js;

/// Admin notification service for real-time updates
/// Listens for new orders and quote requests from the mobile app
class AdminNotificationService {
  static final AdminNotificationService _instance =
      AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  // Audio player for notification sounds
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Stream controllers
  final _newOrdersController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newQuotesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newReturnsController =
      StreamController<Map<String, dynamic>>.broadcast();
  // Explicit event stream for order_return_created (legacy clients expect this name)
  final _orderReturnCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderCountController = StreamController<int>.broadcast();
  final _quoteCountController = StreamController<int>.broadcast();
  final _returnCountController = StreamController<int>.broadcast();

  // Status update streams (for real-time UI updates)
  final _orderStatusUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _quotationStatusUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _returnStatusUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Unified notification stream
  final _notificationsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  // Subscription channels
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _quotesChannel;
  RealtimeChannel? _returnsChannel;
  RealtimeChannel? _notificationsChannel;

  // Counters
  int _newOrderCount = 0;
  int _newQuoteCount = 0;
  int _newReturnCount = 0;
  int _unreadNotificationCount = 0;

  // Public streams
  Stream<Map<String, dynamic>> get newOrdersStream =>
      _newOrdersController.stream;
  Stream<Map<String, dynamic>> get newQuotesStream =>
      _newQuotesController.stream;
  Stream<Map<String, dynamic>> get newReturnsStream =>
      _newReturnsController.stream;
  Stream<Map<String, dynamic>> get orderReturnCreatedStream =>
      _orderReturnCreatedController.stream;
  Stream<int> get orderCountStream => _orderCountController.stream;
  Stream<int> get quoteCountStream => _quoteCountController.stream;
  Stream<int> get returnCountStream => _returnCountController.stream;

  // Status update streams (for real-time UI updates)
  Stream<Map<String, dynamic>> get orderStatusUpdatedStream =>
      _orderStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get quotationStatusUpdatedStream =>
      _quotationStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get returnStatusUpdatedStream =>
      _returnStatusUpdatedController.stream;

  // Unified notification streams
  Stream<Map<String, dynamic>> get notificationsStream =>
      _notificationsController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  bool _isInitialized = false;
  SupabaseClient? _supabase;
  bool _notificationPermissionGranted = false;

  /// Request browser notification permission
  Future<void> _requestNotificationPermission() async {
    try {
      final permission = js.context.callMethod('eval', ['typeof Notification']);
      if (permission == 'undefined') {
        print('Browser notifications not supported');
        return;
      }
      
      final currentPermission = js.context['Notification']['permission'];
      if (currentPermission == 'granted') {
        _notificationPermissionGranted = true;
        print('✅ Notification permission already granted');
      } else if (currentPermission == 'default') {
        // Request permission
        try {
          html.Notification.requestPermission().then((perm) {
            _notificationPermissionGranted = (perm == 'granted');
            print('Notification permission result: $perm');
          });
        } catch (e) {
          print('Error requesting permission: $e');
        }
      }
    } catch (e) {
      print('Notification permission error: $e');
    }
  }

  /// Play attention-grabbing alert sound
  Future<void> _playAlertSound() async {
    try {
      // Stop any currently playing sound
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Play LOUD attention-grabbing alert sound (emergency alert style)
      await _audioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
        volume: 1.0,
      );
      
      print('🔊 LOUD Alert sound played');
    } catch (e) {
      print('Alert sound error (non-critical): $e');
    }
  }

  /// Save notification to database for persistence
  Future<void> _saveNotificationToDatabase(String type, String title, String message, String? entityId) async {
    try {
      if (_supabase == null) return;
      
      await _supabase!.from('notifications').insert({
        'type': type,
        'title': title,
        'message': message,
        'reference_id': entityId,
        'target': 'admin',  // Required field for NotificationService
        'source': 'mobile_app',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Notification saved to database for bell icon');
      
      // Refresh unread count
      await _refreshUnreadCount();
    } catch (e) {
      print('Error saving notification to database: $e');
    }
  }

  /// Show browser notification with sound
  void _showNotification(String title, String body, String type) {
    try {
      // Play custom alert sound FIRST (works after user interaction)
      _playAlertSound();
      
      // Then show browser notification
      if (_notificationPermissionGranted) {
        html.Notification(
          title,
          body: body,
          icon: 'https://img.icons8.com/fluency/48/000000/notification.png',
        );
        print('🔔 Notification shown: $title');
      } else {
        print('📢 $title: $body');
      }
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  /// Initialize the notification service
  Future<void> initialize(SupabaseClient supabase) async {
    if (_isInitialized) {
      print('AdminNotificationService already initialized');
      return;
    }

    _supabase = supabase;

    try {
      print('Initializing AdminNotificationService...');

      // Request notification permission first
      await _requestNotificationPermission();

      await _subscribeToOrders();
      await _subscribeToQuoteRequests();
      await _subscribeToReturns();
      await _subscribeToNotifications();
      await _refreshUnreadCount();
      
      // Automatically generate billing reminders
      _triggerBillingReminders();

      _isInitialized = true;
      print('AdminNotificationService initialized successfully');
    } catch (e) {
      print('Error initializing AdminNotificationService: $e');
    }
  }

  Future<void> _triggerBillingReminders() async {
    try {
      if (_supabase == null) return;
      print('Triggering daily billing reminders...');
      await _supabase!.rpc('generate_billing_reminders');
      print('Billing reminders generated successfully');
    } catch (e) {
      print('Error generating billing reminders: $e');
    }
  }

  /// Subscribe to new orders and order status updates
  Future<void> _subscribeToOrders() async {
    if (_supabase == null) return;

    try {
      _ordersChannel = _supabase!
          .channel('admin_orders_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              print('New order detected!');
              final newOrder = payload.newRecord;

              final title = 'New Order Received!';
              final message = 'From ${newOrder['customer_name']} - ₹${newOrder['total_amount']}';

              // Save to database for bell icon
              await _saveNotificationToDatabase('order', title, message, newOrder['id']);

              // Show browser notification
              _showNotification('🛒 $title', message, 'order');

              // Emit unified notification for bell widget
              _notificationsController.add({
                'type': 'order',
                'title': title,
                'message': message,
                'entity_id': newOrder['id'],
                'created_at': newOrder['created_at'],
              });

              // Increment counter
              _newOrderCount++;
              _orderCountController.add(_newOrderCount);

              // Emit new order event
              _newOrdersController.add(newOrder);

              // Log for debugging
              print('Order ID: ${newOrder['id']}');
              print('Customer: ${newOrder['customer_name']}');
              print('Total: ${newOrder['total_amount']}');
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              print('🔄 Order UPDATE event received from Supabase!');
              final updatedOrder = payload.newRecord;
              final oldOrder = payload.oldRecord;

              print(
                'Old status: ${oldOrder['order_status']}, New status: ${updatedOrder['order_status']}',
              );
              print(
                'Old return_status: ${oldOrder['return_status']}, New return_status: ${updatedOrder['return_status']}',
              );
              print(
                'Old has_return: ${oldOrder['has_return']}, New has_return: ${updatedOrder['has_return']}',
              );

              // Check if status changed OR if return flags changed (important for Returned tab)
              final statusChanged =
                  updatedOrder['order_status'] != oldOrder['order_status'];
              final returnStatusChanged =
                  updatedOrder['return_status'] != oldOrder['return_status'];
              final hasReturnChanged =
                  updatedOrder['has_return'] != oldOrder['has_return'];

              if (statusChanged || returnStatusChanged || hasReturnChanged) {
                // Emit status update event (triggers refresh for Returned tab)
                final updateData = {
                  'entity_type': 'order',
                  'entity_id': updatedOrder['id'],
                  'order_id': updatedOrder['id'],
                  'new_status': updatedOrder['order_status'],
                  'old_status': oldOrder['order_status'],
                  'return_status': updatedOrder['return_status'],
                  'has_return': updatedOrder['has_return'],
                  'has_return_changed': hasReturnChanged,
                  'updated_at': updatedOrder['updated_at'],
                  'order_data': updatedOrder,
                };

                print(
                  '📤 Emitting order update event (status/return changed): $updateData',
                );
                _orderStatusUpdatedController.add(updateData);

                if (hasReturnChanged) {
                  print(
                    '✅ Order ${updatedOrder['id']} has_return changed: ${oldOrder['has_return']} → ${updatedOrder['has_return']}',
                  );
                }
                if (statusChanged) {
                  print(
                    '✅ Order ${updatedOrder['id']} status: ${oldOrder['order_status']} → ${updatedOrder['order_status']}',
                  );
                }
              } else {
                print(
                  '⚠️ Order updated but status/return unchanged, skipping event',
                );
              }
            },
          )
          .subscribe();

      print('Subscribed to orders notifications and status updates');
    } catch (e) {
      print('Error subscribing to orders: $e');
    }
  }

  /// Subscribe to new quote requests and quotation status updates
  Future<void> _subscribeToQuoteRequests() async {
    if (_supabase == null) return;

    try {
      _quotesChannel = _supabase!
          .channel('admin_quotes_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'quote_requests',
            callback: (payload) async {
              print('New quote request detected!');
              final newQuote = payload.newRecord;

              final title = 'New Quote Request';
              final message = 'Product: ${newQuote['product_name']}';

              // Save to database for bell icon
              await _saveNotificationToDatabase('quotation', title, message, newQuote['id']);

              // Show browser notification
              _showNotification('💬 $title', message, 'quote');

              // Emit unified notification for bell widget
              _notificationsController.add({
                'type': 'quotation',
                'title': title,
                'message': message,
                'entity_id': newQuote['id'],
                'created_at': newQuote['created_at'],
              });

              // Increment counter
              _newQuoteCount++;
              _quoteCountController.add(_newQuoteCount);

              // Emit new quote event
              _newQuotesController.add(newQuote);

              // Log for debugging
              print('Quote ID: ${newQuote['id']}');
              print('Product: ${newQuote['product_name']}');
              print('Status: ${newQuote['status']}');
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'quote_requests',
            callback: (payload) {
              print('🔄 Quotation UPDATE event received from Supabase!');
              final updatedQuote = payload.newRecord;
              final oldQuote = payload.oldRecord;

              print(
                'Old status: ${oldQuote['status']}, New status: ${updatedQuote['status']}',
              );
              print(
                'Old admin_status: ${oldQuote['admin_status']}, New admin_status: ${updatedQuote['admin_status']}',
              );

              // Check if status or admin_status changed
              if (updatedQuote['status'] != oldQuote['status'] ||
                  updatedQuote['admin_status'] != oldQuote['admin_status']) {
                // Emit status update event
                final updateData = {
                  'entity_type': 'quotation',
                  'entity_id': updatedQuote['id'],
                  'quotation_id': updatedQuote['id'],
                  'new_status': updatedQuote['status'],
                  'old_status': oldQuote['status'],
                  'admin_status': updatedQuote['admin_status'],
                  'updated_at': updatedQuote['updated_at'],
                  'quotation_data': updatedQuote,
                };

                print('📤 Emitting quotation status update event: $updateData');
                _quotationStatusUpdatedController.add(updateData);

                print(
                  '✅ Quotation ${updatedQuote['id']} status: ${oldQuote['status']} → ${updatedQuote['status']}',
                );
              } else {
                print(
                  '⚠️ Quotation updated but status unchanged, skipping event',
                );
              }
            },
          )
          .subscribe();

      print('Subscribed to quote requests notifications and status updates');
    } catch (e) {
      print('Error subscribing to quote requests: $e');
    }
  }

  /// Reset order count (when admin views orders)
  void resetOrderCount() {
    _newOrderCount = 0;
    _orderCountController.add(0);
    print('Order count reset');
  }

  /// Subscribe to new return requests
  Future<void> _subscribeToReturns() async {
    if (_supabase == null) return;

    try {
      _returnsChannel = _supabase!
          .channel('admin_returns_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'returns',
            callback: (payload) async {
              print('🔄🔄🔄 NEW RETURN REQUEST DETECTED FROM MOBILE APP!');
              final newReturn = payload.newRecord;

              final title = 'New Return Request';
              final message = 'Order ID: ${newReturn['order_id']}';

              // Save to database for bell icon
              await _saveNotificationToDatabase('return', title, message, newReturn['id']);

              // Show browser notification
              _showNotification('🔄 $title', message, 'return');

              // Emit unified notification for bell widget
              _notificationsController.add({
                'type': 'return',
                'title': title,
                'message': message,
                'entity_id': newReturn['id'],
                'created_at': newReturn['created_at'],
              });

              // Increment counter
              _newReturnCount++;
              _returnCountController.add(_newReturnCount);

              // Emit new return event with full details
              final returnEventData = {
                'return_id': newReturn['id'],
                'order_id': newReturn['order_id'],
                'user_id': newReturn['user_id'],
                'return_status': newReturn['return_status'] ?? 'pending',
                'return_reason': newReturn['return_reason'],
                'refund_amount': newReturn['refund_amount'],
                'notes': newReturn['notes'],
                'created_at': newReturn['created_at'],
                'requested_at': newReturn['created_at'],
              };

              print('📤 Emitting return created event: $returnEventData');
              _newReturnsController.add(returnEventData);

              // Also emit a backward-compatible named event `order_return_created` with minimal payload
              try {
                final namedPayload = {
                  'order_id': newReturn['order_id'],
                  'return_id': newReturn['id'],
                  'return_status': newReturn['return_status'] ?? 'pending',
                  'is_partial': newReturn['is_partial'] ?? false,
                  'created_at': newReturn['created_at'],
                };
                _orderReturnCreatedController.add({
                  'event': 'order_return_created',
                  'payload': namedPayload,
                });
                print(
                  '📤 Emitted order_return_created named event: $namedPayload',
                );
              } catch (e) {
                print('⚠️ Failed to emit named order_return_created event: $e');
              }

              // Log for debugging
              print('✅ Return ID: ${newReturn['id']}');
              print('✅ Order ID: ${newReturn['order_id']}');
              print('✅ Status: ${newReturn['return_status']}');
              print('✅ Refund Amount: ${newReturn['refund_amount']}');
              print(
                '🔄 This should trigger orders list refresh in admin panel',
              );
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'returns',
            callback: (payload) {
              print('🔄 Return request updated!');
              final updatedReturn = payload.newRecord;
              final oldReturn = payload.oldRecord;

              // Check if status changed
              if (updatedReturn['return_status'] !=
                  oldReturn['return_status']) {
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

                print(
                  'Return ${updatedReturn['id']} status: ${oldReturn['return_status']} → ${updatedReturn['return_status']}',
                );
              }

              // Also emit to newReturnsController for backward compatibility
              _newReturnsController.add({
                'return_id': updatedReturn['id'],
                'order_id': updatedReturn['order_id'],
                'user_id': updatedReturn['user_id'],
                'return_status': updatedReturn['return_status'] ?? 'pending',
                'return_reason': updatedReturn['return_reason'],
                'refund_amount': updatedReturn['refund_amount'],
                'notes': updatedReturn['notes'],
                'updated_at': updatedReturn['updated_at'],
              });
            },
          )
          .subscribe();

      print('Subscribed to returns notifications');
    } catch (e) {
      print('Error subscribing to returns: $e');
    }
  }

  /// Reset quote count (when admin views quotes)
  void resetQuoteCount() {
    _newQuoteCount = 0;
    _quoteCountController.add(0);
    print('Quote count reset');
  }

  /// Reset return count (when admin views returns)
  void resetReturnCount() {
    _newReturnCount = 0;
    _returnCountController.add(0);
    print('Return count reset');
  }

  /// Get current order count
  int get orderCount => _newOrderCount;

  /// Get current quote count
  int get quoteCount => _newQuoteCount;

  /// Get current return count
  int get returnCount => _newReturnCount;

  /// Get current unread notification count
  int get unreadCount => _unreadNotificationCount;

  /// Subscribe to notifications table
  Future<void> _subscribeToNotifications() async {
    if (_supabase == null) return;

    try {
      _notificationsChannel = _supabase!
          .channel('admin_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'target',
              value: 'admin',
            ),
            callback: (payload) {
              print('🔔 New notification received!');
              final notification = payload.newRecord;

              // Increment unread count
              _unreadNotificationCount++;
              _unreadCountController.add(_unreadNotificationCount);

              // Emit notification
              _notificationsController.add(notification);

              print('Notification: ${notification['title']}');
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'target',
              value: 'admin',
            ),
            callback: (payload) {
              // Update unread count if notification was marked as read
              if (payload.newRecord['is_read'] == true &&
                  payload.oldRecord['is_read'] == false) {
                _unreadNotificationCount = (_unreadNotificationCount - 1)
                    .clamp(0, double.infinity)
                    .toInt();
                _unreadCountController.add(_unreadNotificationCount);
              }
            },
          )
          .subscribe();

      print('Subscribed to notifications');
    } catch (e) {
      print('Error subscribing to notifications: $e');
    }
  }

  /// Refresh unread count from database
  Future<void> _refreshUnreadCount() async {
    if (_supabase == null) return;

    try {
      final response = await _supabase!
          .from('notifications')
          .select('id')
          .eq('target', 'admin')
          .eq('is_read', false);

      _unreadNotificationCount = (response as List).length;
      _unreadCountController.add(_unreadNotificationCount);
    } catch (e) {
      print('Error refreshing unread count: $e');
    }
  }

  /// Refresh unread count (public method)
  Future<void> refreshUnreadCount() async {
    await _refreshUnreadCount();
  }

  /// Dispose all subscriptions
  Future<void> dispose() async {
    print('Disposing AdminNotificationService...');

    await _ordersChannel?.unsubscribe();
    await _quotesChannel?.unsubscribe();
    await _returnsChannel?.unsubscribe();
    await _notificationsChannel?.unsubscribe();

    await _newOrdersController.close();
    await _newQuotesController.close();
    await _newReturnsController.close();
    await _orderReturnCreatedController.close();
    await _orderCountController.close();
    await _quoteCountController.close();
    await _returnCountController.close();
    await _orderStatusUpdatedController.close();
    await _quotationStatusUpdatedController.close();
    await _returnStatusUpdatedController.close();
    await _notificationsController.close();
    await _unreadCountController.close();

    _isInitialized = false;
    print('AdminNotificationService disposed');
  }
}

/// Provider for admin notification service
final adminNotificationServiceProvider = Provider<AdminNotificationService>((
  ref,
) {
  return AdminNotificationService();
});

/// Provider for new order count
final newOrderCountProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(adminNotificationServiceProvider);
  yield service.orderCount;
  yield* service.orderCountStream;
});

/// Provider for new quote count
final newQuoteCountProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(adminNotificationServiceProvider);
  yield service.quoteCount;
  yield* service.quoteCountStream;
});

/// Provider for new return requests stream
final newReturnsStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(adminNotificationServiceProvider);
  return service.newReturnsStream;
});

/// Provider for named order_return_created events
final orderReturnCreatedStreamProvider = StreamProvider<Map<String, dynamic>>((
  ref,
) {
  final service = ref.watch(adminNotificationServiceProvider);
  return service.orderReturnCreatedStream;
});

/// Provider for new return count
final newReturnCountProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(adminNotificationServiceProvider);
  yield service.returnCount;
  yield* service.returnCountStream;
});

/// Provider for unified notifications stream
final adminNotificationsStreamProvider = StreamProvider<Map<String, dynamic>>((
  ref,
) {
  final service = ref.watch(adminNotificationServiceProvider);
  return service.notificationsStream;
});

/// Provider for unread notification count
final unreadNotificationCountProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(adminNotificationServiceProvider);
  // Yield current count immediately so UI doesn't wait for next event
  yield service.unreadCount;
  yield* service.unreadCountStream;
});

/// Provider for order status updates stream
final orderStatusUpdatedStreamProvider = StreamProvider<Map<String, dynamic>>((
  ref,
) {
  final service = ref.watch(adminNotificationServiceProvider);
  return service.orderStatusUpdatedStream;
});

/// Provider for quotation status updates stream
final quotationStatusUpdatedStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
      final service = ref.watch(adminNotificationServiceProvider);
      return service.quotationStatusUpdatedStream;
    });

/// Provider for return status updates stream
final returnStatusUpdatedStreamProvider = StreamProvider<Map<String, dynamic>>((
  ref,
) {
  final service = ref.watch(adminNotificationServiceProvider);
  return service.returnStatusUpdatedStream;
});
