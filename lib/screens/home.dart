import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../widgets/streak_chart.dart';
import '../services/streak_service.dart';
import '../widgets/stat_card.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import 'lessons_page.dart';
import 'review_page.dart';
import 'words_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';

class Home extends StatefulWidget {
  /// Tab to open first (used by the widget "review" deep link).
  final int initialTab;
  const Home({super.key, this.initialTab = 0});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late int tab;
  StreamSubscription<Uri?>? _widgetClicks;
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
    tab = widget.initialTab;
    AppSettings.revision.addListener(_onSettingsChanged);
    // Widget taps while the app is alive (e.g. the review button).
    try {
      _widgetClicks = HomeWidget.widgetClicked.listen((uri) {
        if (uri != null && (uri.host == 'review' || uri.path == '/review')) {
          if (mounted) {
            setState(() {
              tab = 2;
              _revSeed++;
            });
          }
        }
      }, onError: (_) {});
    } catch (_) {
      // Not supported on this platform; ignore.
    }
  }

  @override
  void dispose() {
    AppSettings.revision.removeListener(_onSettingsChanged);
    _widgetClicks?.cancel();
    super.dispose();
  }

  /// Any settings write rebuilds the data tabs at once, so the user
  /// sees the result immediately without manual refresh.
  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        _dashSeed++;
        _lessSeed++;
        _revSeed++;
      });
    }
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
          appBar: AppBar(title: const Text('WortSchatz'), actions: [
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
  int goal = 10;
  int todayCount = 0;
  int currentStreak = 0;
  int longestStreak = 0;
  List<StreakDay> streakDays = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    level = await AppSettings.level;
    goal = await AppSettings.dailyGoal;
    final x = await VocabularyDb.instance.stats(level: level);
    final sd = await StreakService.getStreak();
    streakDays = await StreakService.getCurrentWeek();
    currentStreak = sd.currentStreak;
    longestStreak = sd.longestStreak;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    todayCount =
        streakDays.where((d) => d.date == today).fold(0, (a, d) => a + d.count);
    if (mounted) setState(() => s = x);
  }

  double get goalProgress =>
      goal <= 0 ? 0 : (todayCount / goal).clamp(0.0, 1.0);

  /// Change the active level right from the dashboard chip.
  /// Persisting routes through AppSettings, so the revision bump
  /// rebuilds every tab and the result is visible immediately.
  Future<void> _changeLevel() async {
    const levels = ['A1', 'A2'];
    final picked = await showDialog<String>(
        context: context,
        builder: (d) =>
            SimpleDialog(title: const Text('انتخاب سطح'), children: [
              for (final l in levels)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(d, l),
                    child: Row(children: [
                      if (l == level) const Icon(Icons.check, size: 20),
                      if (l == level) const SizedBox(width: 8),
                      Text(l, style: const TextStyle(fontSize: 18)),
                    ]))
            ]));
    if (picked != null && picked != level && mounted) {
      await AppSettings.setString('level', picked);
    }
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
                      Text('WortSchatz',
                          style: Theme.of(c)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('یادگیری آلمانی با مرور هوشمند',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      ActionChip(
                          label: Text('سطح فعال: $level'),
                          visualDensity: VisualDensity.compact,
                          onPressed: _changeLevel),
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
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          SizedBox(
                              width: 56,
                              height: 56,
                              child:
                                  Stack(alignment: Alignment.center, children: [
                                CircularProgressIndicator(
                                    value: goalProgress,
                                    strokeWidth: 6,
                                    backgroundColor: Colors.grey.shade300),
                                Text('$todayCount',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ])),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('هدف امروز',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text('$todayCount از $goal واژه',
                                    style: const TextStyle(color: Colors.grey)),
                                if (todayCount >= goal)
                                  const Text('تبریک! هدف امروز کامل شد',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold))
                              ]))
                        ])))),
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
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                            c,
                            MaterialPageRoute(
                                builder: (_) => const StatsPage())),
                        icon: const Icon(Icons.insights_outlined),
                        label: const Text('آمار کامل')))),
          ])));
}
