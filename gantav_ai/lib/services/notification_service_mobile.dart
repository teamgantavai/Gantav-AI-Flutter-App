import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:math';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final List<String> _motivationalQuotes = [
    "The secret of getting ahead is getting started.",
    "Believe you can and you're halfway there.",
    "Don't watch the clock; do what it does. Keep going.",
    "Your limitation—it's only your imagination.",
    "Push yourself, because no one else is going to do it for you.",
    "Great things never come from comfort zones.",
    "Dream it. Wish it. Do it.",
    "Success doesn’t just find you. You have to go out and get it.",
    "The harder you work for something, the greater you’ll feel when you achieve it.",
    "Dream bigger. Do bigger.",
    "Don’t stop when you’re tired. Stop when you’re done.",
    "Wake up with determination. Go to bed with satisfaction.",
    "Do something today that your future self will thank you for.",
    "Little things make big days.",
    "It’s going to be hard, but hard does not mean impossible.",
    "Don’t wait for opportunity. Create it.",
    "Sometimes we’re tested not to show our weaknesses, but to discover our strengths.",
    "The key to success is to focus on goals, not obstacles.",
    "Dream it. Believe it. Build it.",
    "Motivation is what gets you started. Habit is what keeps you going.",
    "Your only limit is you.",
    "Focus on being productive instead of busy.",
    "Work hard in silence, let your success be your noise.",
    "Success is not final; failure is not fatal: It is the courage to continue that counts.",
    "Hardships often prepare ordinary people for an extraordinary destiny.",
  ];

  static Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(settings: initializationSettings);
      
      // Schedule the 3 daily notifications
      await scheduleDailyNotifications();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  static Future<void> scheduleDailyNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();

      await _scheduleDaily(id: 100, title: "Morning Inspiration 🌅", hour: 9, minute: 0);
      await _scheduleDaily(id: 101, title: "Keep Going! 🚀", hour: 14, minute: 0);
      await _scheduleDaily(id: 102, title: "One Last Push 🌙", hour: 20, minute: 0);
    } catch (e) {
      debugPrint('Failed to schedule notifications: $e');
    }
  }

  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required int hour,
    required int minute,
  }) async {
    final randomQuote = _motivationalQuotes[Random().nextInt(_motivationalQuotes.length)];
    
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: randomQuote,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_motivation_channel',
          'Daily Motivation',
          channelDescription: 'Motivational quotes to keep you learning',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
