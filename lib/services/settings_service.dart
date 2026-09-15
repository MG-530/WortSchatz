import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  /// Bumped on every settings write. Home listens to it so any change
  /// (level, audio, goal, …) rebuilds the tabs immediately and the user
  /// sees the result without manual refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void _bump() => revision.value++;

  /// App theme, reactive so Settings changes apply instantly.
  static final ValueNotifier<ThemeMode> theme =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<ThemeMode> get themeMode async {
    switch ((await SharedPreferences.getInstance()).getString('themeMode')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(String v) async {
    await setString('themeMode', v);
    theme.value = await themeMode;
  }

  static Future<bool> get autoPlay async =>
      (await SharedPreferences.getInstance()).getBool('autoPlay') ?? true;
  static Future<bool> get onlineAudio async =>
      (await SharedPreferences.getInstance()).getBool('onlineAudio') ?? false;
  static Future<bool> get articleTts async =>
      (await SharedPreferences.getInstance()).getBool('articleTts') ?? true;
  static Future<int> get dailyGoal async =>
      (await SharedPreferences.getInstance()).getInt('dailyGoal') ?? 10;

  /// Leitner/review audio: 0 = silent, 1 = question + answer side,
  /// 2 = answer side only.
  static Future<int> get leitnerAudio async =>
      (await SharedPreferences.getInstance()).getInt('leitnerAudio') ?? 0;
  static Future<String> get reminder async =>
      (await SharedPreferences.getInstance()).getString('reminder') ?? '20:00';
  static Future<String> get course async =>
      (await SharedPreferences.getInstance()).getString('course') ??
      'Starten Wir';
  static Future<String> get book async =>
      (await SharedPreferences.getInstance()).getString('book') ??
      'Starten Wir A1';
  static Future<String> get level async =>
      (await SharedPreferences.getInstance()).getString('level') ?? 'A1';
  static Future<void> setBool(String key, bool value) async {
    await (await SharedPreferences.getInstance()).setBool(key, value);
    _bump();
  }

  static Future<void> setInt(String key, int value) async {
    await (await SharedPreferences.getInstance()).setInt(key, value);
    _bump();
  }

  static Future<void> setString(String key, String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
    _bump();
  }
}
