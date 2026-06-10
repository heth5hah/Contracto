import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../main.dart' show supabaseProvider;
import '../../../../core/services/admin_notification_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/models/notification_model.dart';

/// Notification bell widget with badge and dropdown
class NotificationBellWidget extends ConsumerStatefulWidget {
  const NotificationBellWidget({super.key});

  @override
  ConsumerState<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends ConsumerState<NotificationBellWidget> {
  StreamSubscription? _notificationSubscription;
  bool _isLoading = false;
  List<NotificationModel> _notifications = [];
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _hideDropdown();
    super.dispose();
  }

  void _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final service = NotificationService(supabase);
      final notifications = await service.getAdminNotifications(limit: 20);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _listenToNotifications() {
    final service = ref.read(adminNotificationServiceProvider);
    _notificationSubscription = service.notificationsStream.listen((notificationData) {
      // Play sound
      _playNotificationSound(notificationData['type'] as String? ?? 'other');
      
      // Show toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(_getNotificationIcon(notificationData['type'] as String? ?? 'other')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notificationData['title'] as String? ?? 'New Notification',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        notificationData['message'] as String? ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
      
      // Refresh notifications list
      _loadNotifications();
    });
  }

  void _playNotificationSound(String type) {
    // Play different sounds based on notification type
    // Using system sounds for now (can be replaced with custom audio files)
    HapticFeedback.mediumImpact();
    
    // In a real implementation, you would use audio_player package:
    // AudioPlayer().play(AssetSource('sounds/notification_$type.mp3'));
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_cart;
      case 'quotation':
        return Icons.request_quote;
      case 'return':
        return Icons.assignment_return;
      case 'refund':
        return Icons.payment;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + size.height + 8,
        right: MediaQuery.of(context).size.width - offset.dx - size.width,
        width: 400,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _markAllAsRead(),
                            child: const Text('Mark all read'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _hideDropdown,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Notifications list
                Flexible(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _notifications.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No notifications'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final notification = _notifications[index];
                                return _NotificationItem(
                                  notification: notification,
                                  onTap: () => _handleNotificationTap(notification),
                                  onMarkRead: () => _markAsRead(notification.id),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleNotificationTap(NotificationModel notification) {
    _markAsRead(notification.id);
    _hideDropdown();

    // Navigate based on notification type
    switch (notification.type) {
      case 'order':
        if (notification.referenceId != null) {
          context.go('/orders');
          // Could navigate to specific order details if route exists
        }
        break;
      case 'quotation':
        context.go('/quotations');
        break;
      case 'return':
        context.go('/orders');
        break;
      default:
        break;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final service = NotificationService(supabase);
      await service.markAsRead(notificationId);
      _loadNotifications();
      ref.read(adminNotificationServiceProvider).refreshUnreadCount();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final service = NotificationService(supabase);
      await service.markAllAsRead();
      _loadNotifications();
      ref.read(adminNotificationServiceProvider).refreshUnreadCount();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);

    return unreadCountAsync.when(
      data: (unreadCount) => Stack(
        key: _buttonKey,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _toggleDropdown,
          ),
          if (unreadCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      loading: () => IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: _toggleDropdown,
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: _toggleDropdown,
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onMarkRead();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Colors.blue.shade50,
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _getIcon(notification.type),
              color: _getIconColor(notification.type),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_cart;
      case 'quotation':
        return Icons.request_quote;
      case 'return':
        return Icons.assignment_return;
      case 'refund':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'order':
        return Colors.green;
      case 'quotation':
        return Colors.blue;
      case 'return':
        return Colors.orange;
      case 'refund':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}


