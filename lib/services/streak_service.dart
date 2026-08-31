import 'package:shared_preferences/shared_preferences.dart';

class StreakData {
  final int currentStreak;
  final int longestStreak;
  final int lastStudyDate;

  StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastStudyDate,
  });
}

class StreakService {
  static const _keyStreak = 'studyStreak';
  static const _keyLongestStreak = 'longestStreak';
  static const _keyLastStudyDate = 'lastStudyDate';
  static const _keyDailyCount = 'dailyCount_';

  static Future<StreakData> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return StreakData(
      currentStreak: prefs.getInt(_keyStreak) ?? 0,
      longestStreak: prefs.getInt(_keyLongestStreak) ?? 0,
      lastStudyDate: prefs.getInt(_keyLastStudyDate) ?? 0,
    );
  }

  static Future<void> recordStudySession({int wordsStudied = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final todayInt = today.year * 10000 + today.month * 100 + today.day;

    final lastDate = prefs.getInt(_keyLastStudyDate) ?? 0;
    int currentStreak = prefs.getInt(_keyStreak) ?? 0;
    int longestStreak = prefs.getInt(_keyLongestStreak) ?? 0;

    if (lastDate == todayInt) {
      // Already studied today, just increment daily count
      final count = prefs.getInt('$_keyDailyCount$todayKey') ?? 0;
      await prefs.setInt('$_keyDailyCount$todayKey', count + wordsStudied);
      return;
    }

    final yesterdayInt = todayInt - 1;
    if (lastDate == yesterdayInt) {
      currentStreak++;
    } else {
      currentStreak = 1;
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    await prefs.setInt(_keyStreak, currentStreak);
    await prefs.setInt(_keyLongestStreak, longestStreak);
    await prefs.setInt(_keyLastStudyDate, todayInt);
    await prefs.setInt('$_keyDailyCount$todayKey', wordsStudied);
  }

  static Future<List<int>> getLast7Days() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final List<int> days = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = _dateKey(day);
      final count = prefs.getInt('$_keyDailyCount$key') ?? 0;
      days.add(count);
    }
    return days;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStreak);
    await prefs.remove(_keyLongestStreak);
    await prefs.remove(_keyLastStudyDate);
  }

  static String _dateKey(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}