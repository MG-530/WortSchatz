import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static Future<bool> get autoPlay async =>
      (await SharedPreferences.getInstance()).getBool('autoPlay') ?? true;
  static Future<bool> get onlineAudio async =>
      (await SharedPreferences.getInstance()).getBool('onlineAudio') ?? false;
  static Future<bool> get articleTts async =>
      (await SharedPreferences.getInstance()).getBool('articleTts') ?? true;
  static Future<int> get dailyGoal async =>
      (await SharedPreferences.getInstance()).getInt('dailyGoal') ?? 10;
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
  static Future<void> setBool(String key, bool value) async =>
      await (await SharedPreferences.getInstance()).setBool(key, value);
  static Future<void> setInt(String key, int value) async =>
      await (await SharedPreferences.getInstance()).setInt(key, value);
  static Future<void> setString(String key, String value) async =>
      await (await SharedPreferences.getInstance()).setString(key, value);
}
