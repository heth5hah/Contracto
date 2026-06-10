import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Schedules local push notifications for credit order payment reminders.
///
/// Reminder frequency adapts to the admin-set [paymentDueDays]:
///   >= 15 days  → every 5 days
///   5–14 days   → every 3 days
///   < 5 days    → every day
///   Always fires on the day before and the due day itself.
class CreditNotificationService {
  static final CreditNotificationService _instance =
      CreditNotificationService._internal();
  factory CreditNotificationService() => _instance;
  CreditNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Base notification ID range for credit reminders (1000–1999)
  static const int _baseId = 1000;

  Future<void> initialize() async {
    if (_isInitialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) =>
          debugPrint('Credit reminder tapped: ${r.payload}'),
    );
    _isInitialized = true;
    debugPrint('CreditNotificationService initialized');
  }

  /// Schedule reminders for a credit order.
  ///
  /// [dueDate] — the payment deadline
  /// [paymentDueDays] — how many days the admin granted (drives frequency)
  /// [orderRef] — short order reference for the notification text
  /// [amount] — order amount for the notification body
  Future<void> scheduleCreditReminders({
    required DateTime dueDate,
    required int paymentDueDays,
    String orderRef = '',
    double amount = 0,
  }) async {
    if (!_isInitialized) await initialize();

    // Cancel any previous reminders before rescheduling
    await cancelReminders();

    final now = DateTime.now();

    // Determine reminder interval
    final int interval;
    if (paymentDueDays >= 15) {
      interval = 5;
    } else if (paymentDueDays >= 5) {
      interval = 3;
    } else {
      interval = 1;
    }

    final amountStr = amount > 0 ? '₹${amount.toStringAsFixed(0)}' : 'your credit';
    final orderStr = orderRef.isNotEmpty ? ' for Order #$orderRef' : '';

    int notifId = _baseId;
    int reminderNumber = 0;

    // Walk backwards from (dueDate - interval) to schedule all interval reminders
    // e.g. given 15 days → notify at 15, 10, 5 days before due (all at 9 AM)
    for (int daysLeft = paymentDueDays; daysLeft > 1; daysLeft -= interval) {
      final reminderDate = dueDate.subtract(Duration(days: daysLeft - 1));
      final scheduled = DateTime(
        reminderDate.year, reminderDate.month, reminderDate.day, 9, 0,
      );
      if (scheduled.isAfter(now)) {
        await _schedule(
          id: notifId++,
          title: 'Payment Reminder$orderStr',
          body: '$daysLeft day${daysLeft == 1 ? '' : 's'} left to pay $amountStr.',
          scheduledDate: scheduled,
        );
        reminderNumber++;
      }
    }

    // Day-before reminder at 9 AM
    final dayBefore = DateTime(dueDate.year, dueDate.month, dueDate.day - 1, 9, 0);
    if (dayBefore.isAfter(now)) {
      await _schedule(
        id: notifId++,
        title: '🟠 Last Chance$orderStr',
        body: 'Payment of $amountStr is due TOMORROW. Please transfer now.',
        scheduledDate: dayBefore,
      );
    }

    // Due day reminder at 9 AM
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
    if (dueDay.isAfter(now)) {
      await _schedule(
        id: notifId++,
        title: '🔴 Payment Due TODAY$orderStr',
        body: 'Payment of $amountStr is due today. Pay immediately to avoid account freeze.',
        scheduledDate: dueDay,
      );
    }

    debugPrint(
        'Scheduled $reminderNumber interval reminders + day-before + due-day for order $orderRef (${paymentDueDays}d window)');
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'credit_reminders',
            'Credit Payment Reminders',
            channelDescription: 'Notifications for credit payment deadlines',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF4F46E5),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Scheduled notification $id: "$title" at $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling notification $id: $e');
    }
  }

  /// Cancel all credit reminder notifications (IDs 1000–1999).
  Future<void> cancelReminders() async {
    if (!_isInitialized) await initialize();
    for (int id = _baseId; id < _baseId + 100; id++) {
      await _plugin.cancel(id);
    }
    debugPrint('Cancelled all credit reminders');
  }
}
