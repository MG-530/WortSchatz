import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/streak_service.dart';
import '../widgets/header.dart';

/// Full statistics: answer accuracy (global + today), per-level
/// mastery and a 30-day activity chart. Accuracy is tracked forward
/// from the update that introduced it (older sessions predate it).
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int total = 0, correct = 0, todayTotal = 0, todayCorrect = 0;
  Map<String, int> a1 = {}, a2 = {};
  List<StreakDay> month = [];
  int currentStreak = 0, longestStreak = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ans = await StreakService.answerStats();
    final s1 = await VocabularyDb.instance.stats(level: 'A1');
    final s2 = await VocabularyDb.instance.stats(level: 'A2');
    final days = await StreakService.getDays(30);
    final sd = await StreakService.getStreak();
    if (!mounted) return;
    setState(() {
      total = ans.total;
      correct = ans.correct;
      todayTotal = ans.todayTotal;
      todayCorrect = ans.todayCorrect;
      a1 = s1;
      a2 = s2;
      month = days;
      currentStreak = sd.currentStreak;
      longestStreak = sd.longestStreak;
      loaded = true;
    });
  }

  double get accuracy => total <= 0 ? 0 : correct / total;
  double get todayAccuracy => todayTotal <= 0 ? 0 : todayCorrect / todayTotal;

  Widget levelCard(String title, Map<String, int> s, Color color) {
    final t = s['total'] ?? 0;
    final learned = s['learned'] ?? 0;
    final due = s['due'] ?? 0;
    final frac = t <= 0 ? 0.0 : (learned / t).clamp(0.0, 1.0);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.menu_book, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$learned از $t',
                    style: const TextStyle(color: Colors.grey))
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: frac,
                  backgroundColor: Colors.grey.shade300,
                  color: color),
              const SizedBox(height: 8),
              Text('$due واژه آماده مرور',
                  style: const TextStyle(fontSize: 13, color: Colors.grey))
            ])));
  }

  Widget accuracyRow(String label, int ok, int all) {
    final frac = all <= 0 ? 0.0 : (ok / all).clamp(0.0, 1.0);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
              width: 64,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
              child: LinearProgressIndicator(
                  value: frac, backgroundColor: Colors.grey.shade300)),
          const SizedBox(width: 8),
          SizedBox(
              width: 96,
              child: Text(
                  all <= 0 ? '—' : '${(frac * 100).round()}٪ ($ok از $all)',
                  textDirection: ui.TextDirection.rtl,
                  style: const TextStyle(fontWeight: FontWeight.bold)))
        ]));
  }

  @override
  Widget build(BuildContext c) {
    final counts = [for (final d in month) d.count];
    final maxBar = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
    final monthTotal = counts.fold<int>(0, (a, b) => a + b);
    return Scaffold(
        appBar: AppBar(title: const Text('آمار کامل')),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                const Header('دقت جواب‌ها',
                    subtitle:
                        'از وقتی شمارش فعال شده (جلسات قدیمی حساب نیستند)'),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              accuracyRow('کل', correct, total),
                              accuracyRow('امروز', todayCorrect, todayTotal),
                            ])))),
                const Header('پیشرفت هر سطح'),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      levelCard('A1', a1, Colors.blue),
                      const SizedBox(height: 8),
                      levelCard('A2', a2, Colors.green),
                    ])),
                Header('سی روز اخیر', subtitle: '$monthTotal واژه در ۳۰ روز'),
                SizedBox(
                    height: 150,
                    child: month.isEmpty
                        ? const Center(child: Text('هنوز فعالیتی ثبت نشده'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final d in month)
                                    Container(
                                        width: 12,
                                        height: maxBar > 0
                                            ? 20 + 110 * (d.count / maxBar)
                                            : 8,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        decoration: BoxDecoration(
                                            color: d.count > 0
                                                ? Theme.of(c)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(
                                                        alpha: 0.35 +
                                                            0.65 *
                                                                (maxBar > 0
                                                                    ? d.count /
                                                                        maxBar
                                                                    : 0))
                                                : Colors.grey.shade300,
                                            borderRadius:
                                                BorderRadius.circular(3)))
                                ]))),
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                        '🔥 استریک فعلی: $currentStreak روز • رکورد: $longestStreak روز',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
              ]));
  }
}
