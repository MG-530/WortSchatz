import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/header.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/streak_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsPage> {
  bool auto = true, online = false, articleTts = true;
  int goal = 10, leitnerAudio = 0;
  String time = '20:00', level = 'A1', message = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      auto = p.getBool('autoPlay') ?? true;
      online = p.getBool('onlineAudio') ?? false;
      articleTts = p.getBool('articleTts') ?? true;
      goal = p.getInt('dailyGoal') ?? 10;
      leitnerAudio = p.getInt('leitnerAudio') ?? 0;
      time = p.getString('reminder') ?? '20:00';
      level = p.getString('level') ?? 'A1';
    });
  }

  Future<void> boolSet(String k, bool v) async {
    await AppSettings.setBool(k, v);
    if (mounted) {
      setState(() {
        if (k == 'autoPlay') auto = v;
        if (k == 'onlineAudio') online = v;
        if (k == 'articleTts') articleTts = v;
        message = 'ذخیره شد';
      });
    }
  }

  Future<void> textSet(String k, String v) async {
    await AppSettings.setString(k, v);
    setState(() => message = 'ذخیره شد');
  }

  Future<void> pick() async {
    final a = time.split(':');
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: int.parse(a[0]), minute: int.parse(a[1])));
    if (t != null) {
      time =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      await textSet('reminder', time);
      await NotifyService.scheduleDailyReminder();
    }
  }

  Future<void> backup() async {
    try {
      final rows = await VocabularyDb.instance.backupRows();
      final uri = await FilePicker.saveFile(
          fileName: 'starten_wir_a1_backup.json',
          bytes: Uint8List.fromList(utf8.encode(jsonEncode({
            'format': 'starten-wir-a1-progress-v1',
            'createdAt': DateTime.now().toIso8601String(),
            'level': level,
            'words': rows
          }))),
          type: FileType.custom,
          allowedExtensions: ['json']);
      if (uri == null) return;
      setState(() => message = 'بکاپ ذخیره شد');
    } catch (e) {
      setState(() => message = 'بکاپ با مشکل مواجه شد: $e');
    }
  }

  Future<void> restore() async {
    try {
      final files = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['json']);
      if (files.isEmpty || files.single.path == null) return;
      final data = jsonDecode(await File(files.single.path!).readAsString());
      await VocabularyDb.instance.restoreRows(data['words'] as List);
      setState(() => message = 'بازیابی پیشرفت انجام شد');
    } catch (e) {
      setState(() => message = 'بازیابی با مشکل مواجه شد: $e');
    }
  }

  Future<void> resetLeitner() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('ریست لایتنر'),
                content: const Text(
                    'آیا مطمئن هستید؟ همه واژه‌ها از لایتنر خارج می‌شوند (به حالت پیش‌فرض).'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('ریست'))
                ]));
    if (confirm == true) {
      final rows = await VocabularyDb.instance.backupRows();
      final batch = VocabularyDb.instance.batch();
      for (final raw in rows) {
        final x = Map<String, dynamic>.from(raw as Map);
        // Unenroll everything: back to the default empty-Leitner state.
        batch.update('words', {'box': -1, 'next_review': null},
            where: 'id = ?', whereArgs: [x['id']]);
      }
      await batch.commit(noResult: true);
      await StreakService.reset();
      if (mounted) setState(() => message = 'لایتنر ریست شد');
    }
  }

  Future<void> resetStreak() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('ریست استریک'),
                content: const Text(
                    'رکورد روزهای متوالی مطالعه صفر می‌شود. ادامه می‌دهید؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('ریست'))
                ]));
    if (confirm == true) {
      await StreakService.reset();
      if (mounted) setState(() => message = 'استریک ریست شد');
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('تنظیمات')),
        body: ListView(children: [
          const Header('انتخاب سطح'),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButtonFormField<String>(
                  key: ValueKey('level-$level'),
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'سطح'),
                  items: const [
                    DropdownMenuItem(value: 'A1', child: Text('A1')),
                    DropdownMenuItem(value: 'A2', child: Text('A2'))
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => level = v);
                      textSet('level', v);
                    }
                  })),
          const Divider(),
          SwitchListTile(
              title: const Text('پخش خودکار صدا در یادگیری'),
              value: auto,
              onChanged: (v) => boolSet('autoPlay', v)),
          SwitchListTile(
              title: const Text('استفاده از تلفظ آنلاین'),
              subtitle: const Text(
                  'در صورت نبود اینترنت، تلفظ آفلاین استفاده می‌شود'),
              value: online,
              onChanged: (v) => boolSet('onlineAudio', v)),
          SwitchListTile(
              title: const Text('تلفظ همراه با ارتیکل'),
              subtitle: const Text('روشن: «der Apfel» — خاموش: فقط «Apfel»'),
              value: articleTts,
              onChanged: (v) => boolSet('articleTts', v)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButtonFormField<int>(
                  key: ValueKey('leitnerAudio-$leitnerAudio'),
                  initialValue: leitnerAudio,
                  decoration:
                      const InputDecoration(labelText: 'صدا در لایتنر و کوئیز'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('بی‌صدا')),
                    DropdownMenuItem(
                        value: 1, child: Text('صدا روی کارت و پشت کارت')),
                    DropdownMenuItem(value: 2, child: Text('صدا فقط پشت کارت')),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await AppSettings.setInt('leitnerAudio', v);
                      if (mounted) {
                        setState(() {
                          leitnerAudio = v;
                          message = 'ذخیره شد';
                        });
                      }
                    }
                  })),
          ListTile(
              title: const Text('زمان یادآوری مرور'),
              subtitle: Text(time),
              trailing: const Icon(Icons.notifications_active),
              onTap: pick),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButtonFormField<int>(
                  key: ValueKey('goal-$goal'),
                  initialValue: goal,
                  decoration:
                      const InputDecoration(labelText: 'هدف روزانه (واژه)'),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 واژه')),
                    DropdownMenuItem(value: 10, child: Text('10 واژه')),
                    DropdownMenuItem(value: 15, child: Text('15 واژه')),
                    DropdownMenuItem(value: 20, child: Text('20 واژه')),
                    DropdownMenuItem(value: 30, child: Text('30 واژه')),
                    DropdownMenuItem(value: 50, child: Text('50 واژه')),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await AppSettings.setInt('dailyGoal', v);
                      if (mounted) {
                        setState(() {
                          goal = v;
                          message = 'ذخیره شد';
                        });
                      }
                    }
                  })),
          const Header('پیشرفت و بکاپ'),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton.icon(
                  onPressed: backup,
                  icon: const Icon(Icons.file_download),
                  label: const Text('خروجی بکاپ پیشرفت'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                  onPressed: restore,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('ایمپورت بکاپ پیشرفت'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton.icon(
                  onPressed: resetLeitner,
                  icon: const Icon(Icons.refresh),
                  label: const Text('ریست لایتنر'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                  onPressed: resetStreak,
                  icon: const Icon(Icons.local_fire_department_outlined),
                  label: const Text('ریست استریک'))),
          if (message.isNotEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(message,
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)))
        ]),
      );
}
