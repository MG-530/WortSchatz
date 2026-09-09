import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/streak_chart.dart';
import '../services/streak_service.dart';
import '../widgets/stat_card.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import 'lessons_page.dart';
import 'review_page.dart';
import 'words_page.dart';
import 'settings_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  int _dashSeed = 0, _lessSeed = 0, _revSeed = 0;
  // Tabs are rebuilt (fresh key) whenever selected, so DB changes made
  // elsewhere (add/reset/grading in another tab or Settings) are always
  // visible — no stale box counts. WordsPage keeps its state to preserve
  // the search query (it shows no box data).
  List<Widget> get pages => [
        Dashboard(key: ValueKey('dash$_dashSeed')),
        LessonsPage(key: ValueKey('les$_lessSeed')),
        ReviewPage(key: ValueKey('rev$_revSeed')),
        const WordsPage()
      ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openSettings(BuildContext c) async {
    await Navigator.push(
        c, MaterialPageRoute(builder: (_) => const SettingsPage()));
    setState(() {
      _dashSeed++;
      _lessSeed++;
      _revSeed++;
    });
  }

  @override
  Widget build(BuildContext c) => Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: const Text('Starten Wir A1'), actions: [
            IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _openSettings(c))
          ]),
          body: pages[tab],
          bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() {
                    if (i == 0) _dashSeed++;
                    if (i == 1) _lessSeed++;
                    if (i == 2) _revSeed++;
                    tab = i;
                  }),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'خانه'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'درس‌ها'),
                NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: 'لایتنر'),
                NavigationDestination(
                    icon: Icon(Icons.list_alt_outlined),
                    selectedIcon: Icon(Icons.list_alt),
                    label: 'واژه‌ها'),
              ])));
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, int> s = {};
  String level = 'A1';
  int currentStreak = 0;
  int longestStreak = 0;
  List<int> streakDays = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    level = await AppSettings.level;
    final x = await VocabularyDb.instance.stats(level: level);
    final sd = await StreakService.getStreak();
    streakDays = await StreakService.getLast7Days();
    currentStreak = sd.currentStreak;
    longestStreak = sd.longestStreak;
    if (mounted) setState(() => s = x);
  }

  @override
  Widget build(BuildContext c) => SafeArea(
      child: RefreshIndicator(
          onRefresh: load,
          child: ListView(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Starten Wir A1',
                          style: Theme.of(c)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('یادگیری آلمانی با مرور هوشمند',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Chip(
                          label: Text('سطح فعال: $level'),
                          visualDensity: VisualDensity.compact),
                    ])),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreakChart(
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    days: streakDays)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                    color: const Color(0xfff0ecff),
                    child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                            'یک درس انتخاب کن، واژه‌ها را یاد بگیر و با تمرین و لایتنر تثبیت کن.',
                            style: TextStyle(fontSize: 17))))),
            Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      StatCard('کل واژه‌ها', '${s['total'] ?? 0}',
                          Icons.library_books),
                      StatCard('یادگرفته‌شده', '${s['learned'] ?? 0}',
                          Icons.check_circle),
                      StatCard('جدید', '${s['fresh'] ?? 0}', Icons.fiber_new),
                      StatCard('آماده مرور', '${s['due'] ?? 0}', Icons.today)
                    ])),
          ])));
}
