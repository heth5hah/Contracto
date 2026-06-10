import 'package:flutter/foundation.dart';

class PushNotificationService {
  static Future<void> initialize() async {
    debugPrint('Push Notifications temporarily disabled to prevent crash due to missing Firebase config.');
  }
}


