import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    String tzName = 'Asia/Kolkata';
    try {
      final r = await const MethodChannel('flutter_native_timezone').invokeMethod<String>('getLocalTimezone');
      if (r != null && r.isNotEmpty) tzName = r;
    } catch (_) {}
    try { tz.setLocalLocation(tz.getLocation(tzName)); } catch (_) { tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); }

    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true),
    ));
    _ready = true;
  }

  static Future<void> scheduleDailyReminders({int morningHour = 8, int eveningHour = 21}) async {
    await _plugin.cancelAll();
    await _schedule(id: 1, hour: morningHour, minute: 0,
      title: '☀️ Morning fintech dose', body: 'Your daily read is ready. 10 minutes.');
    await _schedule(id: 2, hour: eveningHour, minute: 0,
      title: '🌙 Evening fintech dose', body: 'One article before you sleep. Keep the streak alive!');
  }

  static Future<void> showStreakCelebration(int streak) async {
    await _plugin.show(99, '🔥 $streak-day streak!', "You're on fire. Keep learning!",
      const NotificationDetails(
        android: AndroidNotificationDetails('fintech_streak', 'Streak Celebrations',
          channelDescription: 'Streak milestone notifications',
          importance: Importance.defaultImportance, priority: Priority.defaultPriority),
        iOS: DarwinNotificationDetails()));
  }

  static Future<void> _schedule({required int id, required int hour, required int minute,
    required String title, required String body}) async {
    final now  = tz.TZDateTime.now(tz.local);
    var   next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(id, title, body, next,
      NotificationDetails(
        android: AndroidNotificationDetails('fintech_daily', 'Daily Reminders',
          channelDescription: 'Morning and evening fintech reading reminders',
          importance: Importance.high, priority: Priority.high, icon: '@mipmap/ic_launcher'),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time);
  }
}
