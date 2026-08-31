import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/header.dart';
import '../widgets/stat_card.dart';
import '../services/database_service.dart';
import '../models/word.dart';
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
  final pages = const [Dashboard(), LessonsPage(), ReviewPage(), WordsPage()];
  String level = 'A1';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      level = p.getString('level') ?? 'A1';
    });
  }

  @override
  Widget build(BuildContext c) => Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(
              title: const Text('Starten Wir A1'),
              actions: [
                IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.push(
                        c,
                        MaterialPageRoute(
                            builder: (_) => const SettingsPage())))
              ]),
          body: pages[tab],
          bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
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
  List<Word> w = [];
  String level = 'A1';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      level = p.getString('level') ?? 'A1';
    });
    w = await VocabularyDb.instance.all(level: level);
    final x = await VocabularyDb.instance.stats(level: level);
    if (mounted) setState(() => s = x);
  }

  int b(int n) => w.where((x) => x.box == n).length;

  @override
  Widget build(BuildContext c) => SafeArea(
      child: RefreshIndicator(
          onRefresh: load,
          child: ListView(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Starten Wir A1',
                      style: Theme.of(c)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('یادگیری آلمانی با مرور هوشمند',
                      style: const TextStyle(color: Colors.grey)),
                ])),
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
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('نمایششماتیک جعبوهای لایتنر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            SizedBox(
                height: 120,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (int i = 0; i <= 5; i++)
                        Container(
                            width: 116,
                            margin: const EdgeInsets.only(left: 8),
                            child: Card(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                  Text('باکس $i',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text('${b(i)} واژه'),
                                  Text(i == 0 ? 'جدید' : 'مرور')
                                ])))
                    ]))
          ])));
}