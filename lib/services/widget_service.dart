import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'database_service.dart';
import 'settings_service.dart';
import 'streak_service.dart';

/// Home-screen widgets (Android). Refreshed on every app boot and
/// periodically in the background: word of the day (deterministic by
/// date) + streak + due count + daily goal. Tapping opens the app.
class WidgetService {
  static const _androidName = 'WortschatzWidgetReceiver';
  static const _qualifiedName = 'com.wortschatz.app.WortschatzWidgetReceiver';
  static const _streakAndroidName = 'StreakWidgetReceiver';
  static const _streakQualifiedName = 'com.wortschatz.app.StreakWidgetReceiver';

  static Future<void> refresh() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final level = await AppSettings.level;
      final words = await VocabularyDb.instance.all(level: level);
      if (words.isEmpty) return;
      final today = DateTime.now();
      final dayIndex = DateTime(today.year, today.month, today.day)
          .difference(DateTime(2024, 1, 1))
          .inDays;
      final w = words[dayIndex % words.length];
      final stats = await VocabularyDb.instance.stats(level: level);
      final streak = await StreakService.getStreak();
      final days = await StreakService.getLast7Days();
      final todayCount = days.isNotEmpty ? days.last.count : 0;
      final goal = await AppSettings.dailyGoal;
      await HomeWidget.saveWidgetData<String>('word', w.display);
      await HomeWidget.saveWidgetData<String>('meaning', w.persian);
      await HomeWidget.saveWidgetData<String>('stats',
          '🔥 ${streak.currentStreak} • ${stats['due'] ?? 0} آماده مرور');
      await HomeWidget.saveWidgetData<int>('today', todayCount);
      await HomeWidget.saveWidgetData<int>('goal', goal);
      await HomeWidget.saveWidgetData<int>('streak', streak.currentStreak);
      await HomeWidget.updateWidget(
          androidName: _androidName, qualifiedAndroidName: _qualifiedName);
      await HomeWidget.updateWidget(
          androidName: _streakAndroidName,
          qualifiedAndroidName: _streakQualifiedName);
    } catch (e) {
      debugPrint('widget refresh failed: $e');
    }
  }
}
