import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  /// Get all notifications for admin
  Future<List<NotificationModel>> getAdminNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      // Build filter query first
      var filterQuery = _supabase
          .from('notifications')
          .select()
          .eq('target', 'admin');

      // Apply unreadOnly filter before order/limit
      if (unreadOnly) {
        filterQuery = filterQuery.eq('is_read', false);
      }

      // Now apply order and limit
      final response = await filterQuery
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching admin notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('target', 'admin')
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      print('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('target', 'admin')
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Create a notification (for testing or manual creation)
  Future<NotificationModel> createNotification({
    required String source,
    required String target,
    String? userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase
          .from('notifications')
          .insert({
            'source': source,
            'target': target,
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type,
            'reference_id': referenceId,
            'metadata': metadata,
          })
          .select()
          .single();

      return NotificationModel.fromJson(response);
    } catch (e) {
      print('Error creating notification: $e');
      rethrow;
    }
  }
}

