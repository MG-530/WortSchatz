import 'package:shared_preferences/shared_preferences.dart';

/// One day of study activity, dated by the system clock.
class StreakDay {
  final DateTime date;
  final int count;

  /// True for days after today (shown dimmed, never counted).
  final bool future;
  const StreakDay(this.date, this.count, [this.future = false]);
}

/// Persian weekday name from the real system date.
/// DateTime.weekday is Mon=1..Sun=7; the Persian week starts Saturday.
String weekdayFa(DateTime d) => const [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه'
    ][(d.weekday + 1) % 7];

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

  /// Minimum number of graded answers for an *unfinished* session to count
  /// toward the streak. Finished sessions always count (even 1 word).
  /// This keeps brief visits / accidental opens from inflating the streak.
  static const int minAnswersForStreak = 3;

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

    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    final yesterdayInt =
        yesterday.year * 10000 + yesterday.month * 100 + yesterday.day;
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

  /// Last 7 days (oldest → today), each stamped with its real
  /// system-clock date so weekday labels always match reality.
  static Future<List<StreakDay>> getLast7Days() => getDays(7);

  /// Current Persian week, Saturday → Friday. Days after today are
  /// returned with count 0 and future=true (dimmed, never counted).
  static Future<List<StreakDay>> getCurrentWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final saturday = today.subtract(Duration(days: (today.weekday + 1) % 7));
    final List<StreakDay> days = [];
    for (int i = 0; i < 7; i++) {
      final day = saturday.add(Duration(days: i));
      final isFuture = day.isAfter(today);
      var count = 0;
      if (!isFuture) {
        final key = _dateKey(day);
        count = prefs.getInt('$_keyDailyCount$key') ?? 0;
      }
      days.add(StreakDay(day, count, isFuture));
    }
    return days;
  }

  /// Last [n] days (oldest → today) for the heatmap page.
  static Future<List<StreakDay>> getDays(int n) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final List<StreakDay> days = [];

    for (int i = n - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = _dateKey(day);
      final count = prefs.getInt('$_keyDailyCount$key') ?? 0;
      days.add(StreakDay(DateTime(day.year, day.month, day.day), count));
    }
    return days;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStreak);
    await prefs.remove(_keyLongestStreak);
    await prefs.remove(_keyLastStudyDate);
    for (final k
        in prefs.getKeys().where((k) => k.startsWith(_keyDailyCount))) {
      await prefs.remove(k);
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}
