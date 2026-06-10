# Real-Time Notification System - Implementation Guide

## Overview
Comprehensive real-time notification system with sound alerts, badge counts, and push notifications for both Admin Panel and Mobile App.

## Database Setup (MANDATORY - Run First)

### Step 1: Run SQL Migration
```sql
-- Run this file in Supabase SQL Editor:
-- admin+app/create_notifications_system.sql
```

This creates:
- `notifications` table with all required fields
- RLS policies for admin and user access
- Database triggers for automatic notifications:
  - New Order → Admin notification
  - New Quotation → Admin notification
  - New Return → Admin notification
  - Order Status Change → User notification
  - Quotation Status Change → User notification
  - Return Status Change → User notification

## Admin Panel Implementation

### ✅ Completed Features

1. **Notification Service** (`lib/features/notifications/data/services/notification_service.dart`)
   - Fetch admin notifications
   - Get unread count
   - Mark as read / Mark all as read
   - Delete notifications

2. **Notification Model** (`lib/features/notifications/data/models/notification_model.dart`)
   - Complete data model with all fields
   - JSON serialization

3. **Extended AdminNotificationService** (`lib/core/services/admin_notification_service.dart`)
   - Real-time subscription to notifications table
   - Unread count tracking
   - Stream providers for Riverpod

4. **Notification Bell Widget** (`lib/features/notifications/presentation/widgets/notification_bell_widget.dart`)
   - Badge with unread count
   - Dropdown notification list
   - Sound playback (haptic feedback)
   - Toast notifications
   - Navigation to related pages

5. **Header Integration** (`lib/core/navigation/main_layout.dart`)
   - Notification bell added to header
   - Real-time updates

### Features

- ✅ Real-time notifications via Supabase Realtime
- ✅ Badge count showing unread notifications
- ✅ Dropdown list with notification history
- ✅ Sound alerts (haptic feedback)
- ✅ Toast popups for new notifications
- ✅ Mark as read / Mark all as read
- ✅ Navigation to related pages (orders, quotations, returns)
- ✅ Automatic notification creation via database triggers

## Mobile App Implementation

### ✅ Completed Features

1. **Updated Notification Model** (`lib/features/notifications/data/models/notification_model.dart`)
   - Extended with all required fields
   - Type-based categorization

2. **Extended Notification Service** (`lib/features/notifications/data/services/notification_service.dart`)
   - User-specific notifications
   - Unread count
   - Mark as read functionality

3. **Existing Notifications Screen** (`lib/features/notifications/presentation/screens/notifications_screen.dart`)
   - Already implemented
   - Needs real-time updates and sound

### 🔄 To Be Enhanced

1. **Real-time Updates**
   - Already has `RealtimeSyncService.subscribeToUserNotifications()`
   - Needs integration with notification screen

2. **Sound Playback**
   - Add audio_player package
   - Play sounds based on notification type

3. **Push Notifications (FCM)**
   - Firebase Cloud Messaging setup
   - Background notifications
   - Foreground notifications

4. **Notification Badge**
   - Add to app header/navigation
   - Show unread count

## Sound Implementation

### Admin Panel
Currently uses haptic feedback. To add custom sounds:

1. Add audio files to `assets/sounds/`:
   - `notification_order.mp3`
   - `notification_quotation.mp3`
   - `notification_return.mp3`
   - `notification_default.mp3`

2. Update `notification_bell_widget.dart`:
```dart
import 'package:audioplayers/audioplayers.dart';

void _playNotificationSound(String type) {
  final player = AudioPlayer();
  player.play(AssetSource('sounds/notification_$type.mp3'));
}
```

### Mobile App
Similar implementation with audio_player package.

## Push Notifications (FCM) Setup

### Step 1: Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  firebase_messaging: ^14.7.0
  firebase_core: ^2.24.0
```

### Step 2: Initialize FCM
```dart
// lib/core/services/push_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    String? token = await _messaging.getToken();
    print('FCM Token: $token');
    
    // Save token to user profile in Supabase
    // await saveFCMToken(token);
  }

  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // This would typically be done via a backend service
    // or Supabase Edge Function
  }
}
```

### Step 3: Handle Notifications
```dart
// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}

// In main.dart
void main() async {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // ... rest of initialization
}
```

## Testing Checklist

### Admin Panel
- [ ] Run SQL migration
- [ ] Submit order from mobile app → Admin receives notification
- [ ] Submit quotation from mobile app → Admin receives notification
- [ ] Submit return from mobile app → Admin receives notification
- [ ] Badge count updates correctly
- [ ] Sound plays on new notification
- [ ] Toast appears on new notification
- [ ] Dropdown shows notification list
- [ ] Mark as read works
- [ ] Navigation to related pages works

### Mobile App
- [ ] Admin approves quotation → User receives notification
- [ ] Admin confirms order → User receives notification
- [ ] Admin ships order → User receives notification
- [ ] Admin delivers order → User receives notification
- [ ] Admin approves/rejects return → User receives notification
- [ ] Badge count updates correctly
- [ ] Sound plays on new notification
- [ ] Push notification works when app is closed
- [ ] Notification screen shows all notifications
- [ ] Mark as read works

## Notification Types & Icons

| Type | Icon | Color | Sound |
|------|------|-------|-------|
| order | shopping_cart | Green | notification_order.mp3 |
| quotation | request_quote | Blue | notification_quotation.mp3 |
| return | assignment_return | Orange | notification_return.mp3 |
| refund | payment | Purple | notification_refund.mp3 |
| payment | payment | Blue | notification_payment.mp3 |
| system | notifications | Grey | notification_default.mp3 |

## Real-Time Events

### Mobile App → Admin Panel
- `order_created` → Admin notification
- `quotation_created` → Admin notification
- `return_created` → Admin notification

### Admin Panel → Mobile App
- `order_status_changed` → User notification
- `quotation_status_changed` → User notification
- `return_status_changed` → User notification

## Fallback Mechanism

If real-time connection fails:
1. Poll notifications API every 10 seconds
2. On reconnect, sync unread notifications
3. No duplicate notifications

Implementation:
```dart
Timer? _pollTimer;

void _startPolling() {
  _pollTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
    if (!_isRealtimeConnected) {
      await _loadNotifications();
    }
  });
}
```

## Security

- ✅ RLS policies ensure users only see their notifications
- ✅ Admins see all admin-targeted notifications
- ✅ User ID validation on notification creation
- ✅ Role-based access control

## Performance

- ✅ Indexed queries for fast retrieval
- ✅ Pagination (limit 50 notifications)
- ✅ Efficient real-time subscriptions
- ✅ Throttled updates to prevent UI thrashing

## Files Created/Modified

### Database
- `admin+app/create_notifications_system.sql` - Complete database setup

### Admin Panel
- `lib/features/notifications/data/models/notification_model.dart` - Data model
- `lib/features/notifications/data/services/notification_service.dart` - Service
- `lib/features/notifications/presentation/widgets/notification_bell_widget.dart` - UI widget
- `lib/core/services/admin_notification_service.dart` - Extended with notifications
- `lib/core/navigation/main_layout.dart` - Added notification bell

### Mobile App
- `lib/features/notifications/data/models/notification_model.dart` - Updated model
- `lib/features/notifications/data/services/notification_service.dart` - Extended service
- `lib/core/services/realtime_sync_service.dart` - Already has notification subscription

## Next Steps

1. **Run SQL Migration** - Critical first step
2. **Test Admin Notifications** - Submit order/quote/return from mobile app
3. **Test User Notifications** - Change order/quote/return status from admin
4. **Add Custom Sounds** - Optional enhancement
5. **Setup FCM** - For push notifications when app is closed
6. **Add Notification Badge to Mobile App** - In header/navigation

## Troubleshooting

### Notifications not appearing
1. Check if SQL migration ran successfully
2. Verify RLS policies are correct
3. Check Supabase Realtime is enabled
4. Verify user is authenticated
5. Check browser console for errors

### Sound not playing
1. Check device volume
2. Verify audio files exist (if using custom sounds)
3. Check browser permissions for audio
4. Haptic feedback should work even without audio files

### Badge count incorrect
1. Refresh unread count: `ref.read(adminNotificationServiceProvider).refreshUnreadCount()`
2. Check if notifications are being marked as read
3. Verify real-time subscription is active

## Support

For issues or questions:
1. Check Supabase logs
2. Check browser console (admin panel)
3. Check Flutter logs (mobile app)
4. Verify database triggers are active
5. Test with SQL queries directly




