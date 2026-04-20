import 'package:flutter/foundation.dart';

class NotificationService {
  static Future<void> init() async {
    // No-op on Web
    debugPrint('Notifications not supported on Web');
  }

  static Future<void> scheduleDailyNotifications() async {
    // No-op on Web
  }
}
