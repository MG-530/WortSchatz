import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'database_service.dart';
import 'settings_service.dart';

/// Daily review reminder. Android/iOS only; everything is guarded so other
/// platforms (and any failure) silently skip instead of crashing boot.
class NotifyService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const int _dailyId = 1001;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> init() async {
    if (!supported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(
            (await FlutterTimezone.getLocalTimezone()).identifier));
      } catch (_) {
        // Fall back to UTC-based scheduling below.
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
          settings: const InitializationSettings(android: android, iOS: ios));
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _ready = true;
    } catch (e) {
      debugPrint('notify init failed: $e');
    }
  }

  /// One-shot test notification in 10 seconds, for on-device
  /// diagnosis (permission / battery / scheduling). Returns false when
  /// notifications are unavailable here.
  static Future<bool> showTest() async {
    if (!_ready) return false;
    try {
      const details = NotificationDetails(
          android: AndroidNotificationDetails('daily_review', 'یادآوری مرور',
              importance: Importance.max, priority: Priority.high),
          iOS: DarwinNotificationDetails());
      await _plugin.zonedSchedule(
          id: _dailyId + 1,
          title: 'تست یادآوری 🔔',
          body: 'اگه این رو می‌بینی، یادآوری روزانه هم کار می‌کند.',
          scheduledDate:
              tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
      return true;
    } catch (e) {
      debugPrint('notify test failed: $e');
      return false;
    }
  }

  /// (Re)schedule the daily reminder at the user's chosen time.
  /// Called on every boot and whenever the reminder time changes.
  static Future<void> scheduleDailyReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _dailyId);
      final parts = (await AppSettings.reminder).split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = tz.TZDateTime.now(tz.local);
      var at =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      var due = 0;
      try {
        due = (await VocabularyDb.instance.stats())['due'] ?? 0;
      } catch (_) {}
      final body = due > 0
          ? '$due واژه آماده مرور است — استریک را حفظ کن!'
          : 'امروز هم کمی آلمانی بخوان!';
      const details = NotificationDetails(
          android: AndroidNotificationDetails('daily_review', 'یادآوری مرور',
              importance: Importance.max, priority: Priority.high),
          iOS: DarwinNotificationDetails());
      await _plugin.zonedSchedule(
          id: _dailyId,
          title: 'وقت مرور لایتنر!',
          body: body,
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time);
    } catch (e) {
      debugPrint('notify schedule failed: $e');
    }
  }
}
