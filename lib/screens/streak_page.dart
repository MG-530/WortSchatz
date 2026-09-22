import 'package:flutter/material.dart';
import '../services/streak_service.dart';
import '../widgets/header.dart';

/// Full activity heatmap, GitHub-style: columns are weeks (oldest →
/// newest), rows are Saturday → Friday. Color deepens with daily count.
class StreakPage extends StatefulWidget {
  const StreakPage({super.key});
  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  List<StreakDay> days = [];
  int currentStreak = 0;
  int longestStreak = 0;
  bool loaded = false;

  static const rowLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final all = await StreakService.getDays(84);
    final sd = await StreakService.getStreak();
    if (!mounted) return;
    setState(() {
      // Align the first column to Saturday.
      var start = 0;
      while (start < all.length && (all[start].date.weekday + 1) % 7 != 0) {
        start++;
      }
      days = all.sublist(start);
      currentStreak = sd.currentStreak;
      longestStreak = sd.longestStreak;
      loaded = true;
    });
  }

  Color cellColor(BuildContext c, int count) {
    if (count <= 0) {
      return Theme.of(c).brightness == Brightness.dark
          ? Colors.white12
          : Colors.grey.shade300;
    }
    if (count <= 2) return Colors.deepPurple.shade100;
    if (count <= 5) return Colors.deepPurple.shade300;
    if (count <= 9) return Colors.deepPurple.shade500;
    return Colors.deepPurple.shade700;
  }

  @override
  Widget build(BuildContext c) {
    final total = days.fold<int>(0, (a, d) => a + d.count);
    final active = days.where((d) => d.count > 0).length;
    final weeks = <List<StreakDay>>[];
    for (var i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('فعالیت‌ها')),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                const Header('نقشه فعالیت',
                    subtitle: 'هر ستون یک هفته، هر خانه یک روز'),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(spacing: 16, runSpacing: 8, children: [
                      Text('🔥 $currentStreak روز پشت سر هم',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('🏆 رکورد: $longestStreak روز',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('📚 مجموع: $total واژه',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('✅ $active روز فعال',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ])),
                const SizedBox(height: 12),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(children: [
                            for (final label in rowLabels)
                              Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.all(2),
                                  alignment: Alignment.center,
                                  child: Text(label,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)))
                          ]),
                          const SizedBox(width: 4),
                          for (final week in weeks)
                            Column(children: [
                              for (var r = 0; r < 7; r++)
                                Container(
                                    width: 18,
                                    height: 18,
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                        color: r < week.length
                                            ? cellColor(c, week[r].count)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4)),
                                    alignment: Alignment.center,
                                    child: r < week.length && week[r].count > 0
                                        ? Text('${week[r].count}',
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: week[r].count >= 6
                                                    ? Colors.white
                                                    : Colors.black87))
                                        : null)
                            ])
                        ])),
                const SizedBox(height: 16),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('رنگ پررنگ‌تر یعنی مطالعه بیشتر در آن روز',
                        style: TextStyle(color: Colors.grey, fontSize: 13)))
              ]));
  }
}
