import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as pth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VocabularyDb.instance.init();
  runApp(const StartenWirApp());
}

class Word {
  final int id;
  final String german,
      display,
      article,
      persian,
      english,
      pronunciation,
      type,
      gender;
  final List<int> lessons;
  final int box;
  final DateTime? nextReview;
  Word(
      {required this.id,
      required this.german,
      required this.display,
      required this.article,
      required this.persian,
      required this.english,
      required this.pronunciation,
      required this.type,
      required this.gender,
      required this.lessons,
      required this.box,
      this.nextReview});
  factory Word.fromMap(Map<String, dynamic> m) => Word(
      id: m['id'] as int,
      german: m['german'] ?? '',
      display: m['display'] ?? m['german'] ?? '',
      article: m['article'] ?? '',
      persian: m['persian'] ?? '',
      english: m['english'] ?? '',
      pronunciation: m['pronunciation'] ?? '',
      type: m['word_type'] ?? 'other',
      gender: m['gender'] ?? '',
      lessons: (m['lessons'] as String? ?? '')
          .split(',')
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toList(),
      box: m['box'] ?? 0,
      nextReview: m['next_review'] == null
          ? null
          : DateTime.tryParse(m['next_review']));
}

class VocabularyDb {
  VocabularyDb._();
  static final instance = VocabularyDb._();
  Database? _db;
  Future<void> init() async {
    final dbPath = pth.join(await getDatabasesPath(), 'starten_wir_a1.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY, german TEXT, display TEXT, article TEXT, persian TEXT, english TEXT, pronunciation TEXT, word_type TEXT, gender TEXT, lessons TEXT, box INTEGER DEFAULT 0, next_review TEXT)');
    });
    final count = Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM words')) ??
        0;
    if (count == 0) {
      final raw =
          jsonDecode(await rootBundle.loadString('assets/vocab.json')) as List;
      final batch = _db!.batch();
      for (var i = 0; i < raw.length; i++) {
        final x = Map<String, dynamic>.from(raw[i]);
        batch.insert('words', {
          'id': i + 1,
          'german': x['german'] ?? '',
          'display': x['display'] ?? '',
          'article': x['article'] ?? '',
          'persian': x['persian'] ?? '',
          'english': x['english'] ?? '',
          'pronunciation': x['pronunciation'] ?? '',
          'word_type': x['word_type'] ?? 'other',
          'gender': x['gender'] ?? '',
          'lessons': (x['lessons'] as List? ?? []).join(','),
          'box': 0
        });
      }
      await batch.commit(noResult: true);
    }
  }

  Future<List<Word>> all({String query = '', int? lesson}) async {
    var where = <String>[];
    var args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(german LIKE ? OR persian LIKE ? OR english LIKE ?)');
      args += ['%$query%', '%$query%', '%$query%'];
    }
    if (lesson != null) {
      where.add('lessons LIKE ?');
      args.add('%$lesson%');
    }
    final rows = await _db!.query('words',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'id');
    return rows.map(Word.fromMap).toList();
  }

  Future<List<Word>> due() async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db!.rawQuery(
        'SELECT * FROM words WHERE box > 0 AND (next_review IS NULL OR next_review <= ?) ORDER BY next_review LIMIT 30',
        [now]);
    return rows.map(Word.fromMap).toList();
  }

  Future<bool> isDue(Word w) async {
    if (w.box == 0 || w.nextReview == null) return true;
    return !w.nextReview!.isAfter(DateTime.now());
  }

  Future<void> grade(Word w, bool known) async {
    if (!await isDue(w)) return;
    final box = known ? min(5, w.box + 1) : max(0, w.box - 1);
    final days = [0, 1, 2, 4, 7, 14][box];
    final next = box == 0
        ? null
        : DateTime.now().add(Duration(days: days)).toIso8601String();
    await _db!.update('words', {'box': box, 'next_review': next},
        where: 'id = ?', whereArgs: [w.id]);
  }

  Future<List<Map<String, dynamic>>> backupRows() async =>
      await _db!.query('words', orderBy: 'id');
  Future<void> restoreRows(List<dynamic> rows) async {
    final batch = _db!.batch();
    for (final raw in rows) {
      final x = Map<String, dynamic>.from(raw as Map);
      if (x['id'] != null)
        batch.update(
            'words', {'box': x['box'] ?? 0, 'next_review': x['next_review']},
            where: 'id = ?', whereArgs: [x['id']]);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, int>> stats() async {
    final r = await _db!.rawQuery(
        'SELECT COUNT(*) total, SUM(CASE WHEN box > 0 THEN 1 ELSE 0 END) learned, SUM(CASE WHEN box = 0 THEN 1 ELSE 0 END) fresh FROM words');
    final x = r.first;
    return {
      'total': (x['total'] as int?) ?? 0,
      'learned': (x['learned'] as int?) ?? 0,
      'fresh': (x['fresh'] as int?) ?? 0,
      'due': (await due()).length
    };
  }
}

class StartenWirApp extends StatelessWidget {
  const StartenWirApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Starten Wir A1',
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff102a43), brightness: Brightness.light),
          textTheme: GoogleFonts.vazirmatnTextTheme()),
      home: const Home());
}

Color wordColor(Word w) {
  switch (w.gender) {
    case 'masculine':
      return const Color(0xff2979ff);
    case 'feminine':
      return const Color(0xffe85aad);
    case 'neuter':
      return const Color(0xff22a06b);
    case 'plural':
      return const Color(0xffffb300);
  }
  switch (w.type) {
    case 'verb':
      return const Color(0xff7e57c2);
    case 'adjective':
      return const Color(0xffef6c00);
    case 'phrase':
      return const Color(0xff00838f);
    default:
      return const Color(0xff607d8b);
  }
}

String typeLabel(Word w) => w.gender.isNotEmpty
    ? {
          'masculine': 'مذکر',
          'feminine': 'مونث',
          'neuter': 'خنثی',
          'plural': 'جمع'
        }[w.gender] ??
        w.type
    : {
          'verb': 'فعل',
          'adjective': 'صفت',
          'phrase': 'عبارت',
          'noun': 'اسم'
        }[w.type] ??
        'سایر';

class AppSettings {
  static Future<bool> get autoPlay async =>
      (await SharedPreferences.getInstance()).getBool('autoPlay') ?? true;
  static Future<bool> get onlineAudio async =>
      (await SharedPreferences.getInstance()).getBool('onlineAudio') ?? false;
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
}

Future<void> playWord(Word w, {bool online = false}) async {
  if (online) {
    try {
      final p = AudioPlayer();
      await p.play(UrlSource(
          'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=de&q=${Uri.encodeComponent(w.german)}'));
      return;
    } catch (_) {}
  }
  final t = FlutterTts();
  await t.setLanguage('de-DE');
  await t.setSpeechRate(.42);
  await t.speak(w.german);
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final pages = const [Dashboard(), LessonsPage(), ReviewPage(), WordsPage()];
  @override
  Widget build(BuildContext c) => Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Starten Wir A1'), actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => const SettingsPage())))
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
            ]),
      ));
}

class Header extends StatelessWidget {
  final String title, subtitle;
  const Header(this.title, {this.subtitle = '', super.key});
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(c)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600))
      ]));
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, int> s = {};
  List<Word> w = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    w = await VocabularyDb.instance.all();
    final x = await VocabularyDb.instance.stats();
    if (mounted) setState(() => s = x);
  }

  int b(int n) => w.where((x) => x.box == n).length;
  @override
  Widget build(BuildContext c) => SafeArea(
      child: RefreshIndicator(
          onRefresh: load,
          child: ListView(children: [
            const Header('Starten Wir A1',
                subtitle: 'یادگیری آلمانی با مرور هوشمند'),
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
                child: Text('نمای شماتیک جعبه‌های لایتنر',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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

class StatCard extends StatelessWidget {
  final String t, v;
  final IconData icon;
  const StatCard(this.t, this.v, this.icon, {super.key});
  @override
  Widget build(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Theme.of(c).colorScheme.primary),
            const Spacer(),
            Text(v,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(t)
          ])));
}

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});
  @override
  State<LessonsPage> createState() => _LessonsState();
}

class _LessonsState extends State<LessonsPage> {
  List<Word> w = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    w = await VocabularyDb.instance.all();
    if (mounted) setState(() {});
  }

  int count(int l) => w.where((x) => x.lessons.contains(l)).length;
  @override
  Widget build(BuildContext c) => SafeArea(
          child: ListView(children: [
        const Header('درس‌ها', subtitle: 'هر درس را جداگانه انتخاب و یاد بگیر'),
        for (int l = 1; l <= 12; l++)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Card(
                  child: ListTile(
                      leading: const Icon(Icons.chevron_right),
                      title: Text('درس $l — Lektion $l',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${count(l)} واژه'),
                      trailing: CircleAvatar(child: Text('$l')),
                      onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                              builder: (_) => LearnSession(
                                  words: w
                                      .where((x) => x.lessons.contains(l))
                                      .toList(),
                                  title: 'درس $l'))))))
      ]));
}

class LearnSession extends StatefulWidget {
  final List<Word> words;
  final String title;
  const LearnSession({required this.words, required this.title, super.key});
  @override
  State<LearnSession> createState() => _LearnState();
}

class _LearnState extends State<LearnSession> {
  int index = 0;
  bool revealed = false, auto = true, online = false;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    auto = p.getBool('autoPlay') ?? true;
    online = p.getBool('onlineAudio') ?? false;
    if (auto && widget.words.isNotEmpty)
      playWord(widget.words[0], online: online);
    if (mounted) setState(() {});
  }

  void move(int delta) {
    if (widget.words.isEmpty) return;
    setState(() {
      index = (index + delta + widget.words.length) % widget.words.length;
      revealed = false;
    });
    if (auto) playWord(widget.words[index], online: online);
  }

  @override
  Widget build(BuildContext c) {
    if (widget.words.isEmpty)
      return const Scaffold(body: Center(child: Text('این درس واژه‌ای ندارد')));
    final w = widget.words[index];
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('واژه ${index + 1} از ${widget.words.length}'),
              LinearProgressIndicator(value: (index + 1) / widget.words.length),
              Expanded(
                  child: GestureDetector(
                      onTap: () => setState(() => revealed = !revealed),
                      onHorizontalDragEnd: (d) {
                        if (d.primaryVelocity != null)
                          move(d.primaryVelocity! > 0 ? -1 : 1);
                      },
                      child: SizedBox(
                          width: double.infinity,
                          child: Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Chip(
                                            label: Text(typeLabel(w)),
                                            backgroundColor:
                                                wordColor(w).withOpacity(.14)),
                                        const SizedBox(height: 20),
                                        FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(w.display,
                                                textDirection:
                                                    ui.TextDirection.ltr,
                                                maxLines: 2,
                                                style: TextStyle(
                                                    fontSize: 52,
                                                    fontWeight: FontWeight.w800,
                                                    color: wordColor(w)))),
                                        const SizedBox(height: 18),
                                        if (revealed) ...[
                                          const Divider(),
                                          Text(w.persian,
                                              style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold)),
                                          Text(w.english)
                                        ] else
                                          const Text('برای نمایش معنی لمس کن',
                                              style:
                                                  TextStyle(color: Colors.grey))
                                      ])))))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                FilledButton.icon(
                    onPressed: () => move(-1),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('قبلی')),
                IconButton.filledTonal(
                    onPressed: () => playWord(w, online: online),
                    icon: const Icon(Icons.volume_up)),
                FilledButton.icon(
                    onPressed: () => move(1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('بعدی'))
              ])
            ])));
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});
  @override
  State<ReviewPage> createState() => _ReviewState();
}

class _ReviewState extends State<ReviewPage> {
  List<Word> all = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    all = await VocabularyDb.instance.all();
    if (mounted) setState(() {});
  }

  bool due(Word w) =>
      w.box == 0 ||
      w.nextReview == null ||
      !w.nextReview!.isAfter(DateTime.now());
  int total(int b) => all.where((w) => w.box == b).length;
  int ready(int b) => all.where((w) => w.box == b && due(w)).length;
  void choose(int b) {
    final selected = b < 0 ? all : all.where((w) => w.box == b).toList();
    final readyWords = selected.where(due).toList();
    final later = selected.where((w) => !due(w)).toList();
    showModalBottomSheet(
        context: context,
        builder: (sheet) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(b < 0 ? 'مرور همهٔ واژه‌ها' : 'مرور باکس $b',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              ListTile(
                  leading: const Icon(Icons.style),
                  title: const Text('مرور عادی'),
                  subtitle: Text('${readyWords.length} واژه آماده مرور'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReviewSession(
                                words: readyWords,
                                title: b < 0 ? 'مرور آماده' : 'مرور باکس $b',
                                extra: later)));
                  }),
              ListTile(
                  leading: const Icon(Icons.keyboard),
                  title: const Text('مرور نوشتاری'),
                  subtitle: Text('${readyWords.length} واژه آماده نوشتاری'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => WritingReviewSession(
                                words: readyWords,
                                title:
                                    'نوشتاری — ${b < 0 ? 'همه' : 'باکس $b'}')));
                  })
            ])));
  }

  @override
  Widget build(BuildContext c) => SafeArea(
          child: ListView(children: [
        const Header('لایتنر',
            subtitle: 'فقط واژه‌های آماده، طبق زمان‌بندی مرور می‌شوند'),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (int b = 0; b <= 5; b++)
                SizedBox(
                    width: 160,
                    child: Card(
                        child: InkWell(
                            onTap: () => choose(b),
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(children: [
                                  Icon(Icons.inventory_2,
                                      color: Theme.of(c).colorScheme.primary,
                                      size: 30),
                                  Text('باکس $b',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text('${total(b)} واژه'),
                                  Text('${ready(b)} آماده مرور')
                                ])))))
            ])),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
                onPressed: all.isEmpty ? null : () => choose(-1),
                icon: const Icon(Icons.play_arrow),
                label: const Text('مرور آماده')))
      ]));
}

class ReviewSession extends StatefulWidget {
  final List<Word> words;
  final String title;
  final List<Word> extra;
  const ReviewSession(
      {required this.words,
      required this.title,
      this.extra = const [],
      super.key});
  @override
  State<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<ReviewSession> {
  int i = 0;
  bool show = false;
  @override
  Widget build(BuildContext c) {
    if (widget.words.isEmpty)
      return const Scaffold(
          body: Center(child: Text('واژهٔ آماده‌ای برای مرور نیست')));
    final w = widget.words[i];
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('کارت ${i + 1} از ${widget.words.length}'),
              Expanded(
                  child: GestureDetector(
                      onHorizontalDragEnd: (d) {
                        if (d.primaryVelocity != null)
                          setState(() => i = (i +
                                  (d.primaryVelocity! > 0 ? -1 : 1) +
                                  widget.words.length) %
                              widget.words.length);
                      },
                      child: SizedBox(
                          width: double.infinity,
                          child: Card(
                              child: Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(w.display,
                                        textDirection: ui.TextDirection.ltr,
                                        style: TextStyle(
                                            fontSize: 46,
                                            fontWeight: FontWeight.bold,
                                            color: wordColor(w)))),
                                if (show) ...[
                                  const SizedBox(height: 20),
                                  Text(w.persian,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                  Text(w.english)
                                ]
                              ])))))),
              if (!show)
                FilledButton(
                    onPressed: () => setState(() => show = true),
                    child: const Text('نمایش پاسخ'))
              else
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                          onPressed: () => grade(false),
                          child: const Text('بلد نبودم')),
                      FilledButton(
                          onPressed: () => grade(true),
                          child: const Text('بلد بودم'))
                    ])
            ])));
  }

  Future<void> grade(bool ok) async {
    await VocabularyDb.instance.grade(widget.words[i], ok);
    if (i + 1 >= widget.words.length) {
      if (widget.extra.isNotEmpty && mounted) {
        final go = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
                    title: const Text('مرور آماده تمام شد'),
                    content: const Text(
                        'واژه‌های آماده‌نشده را هم مرور می‌کنی؟ در این حالت باکس‌ها تغییر نمی‌کنند.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('خیر')),
                      FilledButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('بله'))
                    ]));
        if (go == true && mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => ReviewSession(
                      words: widget.extra,
                      title: 'مرور غیرآماده',
                      extra: const [])));
        } else if (mounted) Navigator.pop(context);
      } else if (mounted) Navigator.pop(context);
    } else
      setState(() {
        i++;
        show = false;
      });
  }
}

class WritingReviewSession extends StatefulWidget {
  final List<Word> words;
  final String title;
  const WritingReviewSession(
      {required this.words, required this.title, super.key});
  @override
  State<WritingReviewSession> createState() => _WritingReviewState();
}

class _WritingReviewState extends State<WritingReviewSession> {
  int i = 0;
  String typed = '';
  bool hint = false, checked = false, correct = false;
  final input = TextEditingController();
  final tts = FlutterTts();
  late List<String> letters;
  Word get w => widget.words[i];
  @override
  void initState() {
    super.initState();
    lettersForWord();
  }

  void lettersForWord() {
    letters = w.german.replaceAll(' ', '').split('')..shuffle();
  }

  Future<void> listen() async {
    await tts.setLanguage('de-DE');
    await tts.speak(w.german);
  }

  void addLetter(String ch) {
    if (checked) return;
    setState(() {
      typed += ch;
      input.text = typed;
      input.selection = TextSelection.collapsed(offset: typed.length);
    });
  }

  Future<void> submit() async {
    if (checked) return;
    final ok = typed.trim().toLowerCase() == w.german.trim().toLowerCase();
    await VocabularyDb.instance.grade(w, ok);
    setState(() {
      checked = true;
      correct = ok;
    });
  }

  Future<void> unknown() async {
    if (checked) return;
    await VocabularyDb.instance.grade(w, false);
    setState(() {
      checked = true;
      correct = false;
    });
  }

  void next() {
    if (i + 1 >= widget.words.length) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      i++;
      typed = '';
      input.clear();
      hint = false;
      checked = false;
      correct = false;
      lettersForWord();
    });
  }

  @override
  Widget build(BuildContext c) {
    if (widget.words.isEmpty)
      return const Scaffold(
          body: Center(child: Text('واژهٔ آماده‌ای برای مرور نیست')));
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('نوشتاری ${i + 1} از ${widget.words.length}'),
              const SizedBox(height: 12),
              Text(w.persian,
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.bold)),
              Text(w.english, style: TextStyle(color: Colors.grey.shade700)),
              IconButton.filled(
                  onPressed: listen, icon: const Icon(Icons.volume_up)),
              TextField(
                  controller: input,
                  autofocus: true,
                  enabled: !checked,
                  textDirection: ui.TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'آلمانی را تایپ کن',
                      border: OutlineInputBorder())),
              if (hint)
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final ch in letters)
                    ActionChip(
                        label: Text(ch, textDirection: ui.TextDirection.ltr),
                        onPressed: () => addLetter(ch))
                ]),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed:
                            checked ? null : () => setState(() => hint = !hint),
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('راهنما'))),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton(
                        onPressed: checked ? null : submit,
                        child: const Text('بررسی')))
              ]),
              if (!checked)
                OutlinedButton.icon(
                    onPressed: unknown,
                    icon: const Icon(Icons.close),
                    label: const Text('بلد نیستم'))
              else
                Column(children: [
                  Text(
                      correct
                          ? 'درست است'
                          : 'غلط است — واژه به باکس قبلی برگشت',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: correct ? Colors.green : Colors.red)),
                  FilledButton.icon(
                      onPressed: next,
                      icon: const Icon(Icons.arrow_forward),
                      label:
                          Text(i + 1 >= widget.words.length ? 'پایان' : 'بعدی'))
                ])
            ])));
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});
  @override
  State<PracticePage> createState() => _PracticeState();
}

class _PracticeState extends State<PracticePage> {
  List<Word> words = [];
  int mode = 0;
  String writingMode = 'listen';
  final answer = TextEditingController();
  String feedback = '';
  DateTime? started;
  final tts = FlutterTts();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    words = await VocabularyDb.instance.all();
    words.shuffle();
    if (mounted) setState(() {});
  }

  Word? get x => words.isEmpty ? null : words.first;
  Future<void> listen() async {
    if (x != null) {
      await tts.setLanguage('de-DE');
      await tts.speak(x!.german);
    }
  }

  void check(String correct) {
    final ok = answer.text.trim().toLowerCase() == correct.trim().toLowerCase();
    setState(() => feedback = ok ? 'درست است' : 'اشتباه است؛ دوباره تلاش کن');
  }

  @override
  Widget build(BuildContext c) {
    final q = x;
    if (q == null) return const Center(child: CircularProgressIndicator());
    return SafeArea(
        child: ListView(children: [
      const Header('تمرین', subtitle: 'ترجمه و رایتینگ فعال'),
      Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('ترجمه')),
                ButtonSegment(value: 1, label: Text('رایتینگ'))
              ],
              selected: {
                mode
              },
              onSelectionChanged: (s) {
                answer.clear();
                setState(() => mode = s.first);
              })),
      Padding(
          padding: const EdgeInsets.all(20),
          child: mode == 0
              ? Column(children: [
                  Text(q.persian,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  if (started != null)
                    Text(
                        'زمان: ${DateTime.now().difference(started!).inSeconds} ثانیه'),
                  FilledButton(
                      onPressed: () => setState(() => started = DateTime.now()),
                      child: const Text('شروع تایمر')),
                  TextField(
                      controller: answer,
                      textDirection: ui.TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'معنی را به آلمانی بنویس',
                          border: OutlineInputBorder())),
                  FilledButton(
                      onPressed: () => check(q.german),
                      child: const Text('بررسی')),
                  if (feedback.isNotEmpty)
                    Text(feedback,
                        style: TextStyle(
                            color: feedback == 'درست است'
                                ? Colors.green
                                : Colors.red))
                ])
              : Column(children: [
                  DropdownButton<String>(
                      value: writingMode,
                      items: const [
                        DropdownMenuItem(
                            value: 'listen',
                            child: Text('شنیدن و فقط تایپ خود لغت')),
                        DropdownMenuItem(
                            value: 'scramble',
                            child: Text('ساختن از حروف به‌هم‌ریخته'))
                      ],
                      onChanged: (v) {
                        answer.clear();
                        setState(() => writingMode = v ?? 'listen');
                      }),
                  if (writingMode == 'listen') ...[
                    IconButton.filled(
                        onPressed: listen, icon: const Icon(Icons.volume_up)),
                    TextField(
                        controller: answer,
                        autofocus: true,
                        textDirection: ui.TextDirection.ltr,
                        decoration: const InputDecoration(
                            labelText: 'خود لغت آلمانی را تایپ کن',
                            border: OutlineInputBorder()))
                  ] else ...[
                    Wrap(spacing: 8, children: [
                      for (final ch
                          in (q.german.replaceAll(' ', '').split('')
                            ..shuffle()))
                        ActionChip(
                            label: Text(ch),
                            onPressed: () => setState(() => answer.text += ch))
                    ]),
                    TextField(
                        controller: answer,
                        textDirection: ui.TextDirection.ltr,
                        decoration: const InputDecoration(
                            labelText: 'لغت ساخته‌شده',
                            border: OutlineInputBorder()))
                  ],
                  FilledButton(
                      onPressed: () => check(q.german),
                      child: const Text('بررسی')),
                  if (feedback.isNotEmpty)
                    Text(feedback,
                        style: TextStyle(
                            color: feedback == 'درست است'
                                ? Colors.green
                                : Colors.red))
                ]))
    ]));
  }
}

class WordsPage extends StatefulWidget {
  const WordsPage({super.key});
  @override
  State<WordsPage> createState() => _WordsState();
}

class _WordsState extends State<WordsPage> {
  List<Word> w = [];
  String q = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    w = await VocabularyDb.instance.all(query: q);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => SafeArea(
          child: Column(children: [
        const Header('واژه‌ها', subtitle: 'جست‌وجوی همهٔ واژه‌های کتاب'),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
                textDirection: ui.TextDirection.ltr,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'German / Persian / English',
                    border: OutlineInputBorder()),
                onChanged: (v) {
                  q = v;
                  load();
                })),
        Expanded(
            child: ListView.builder(
                itemCount: w.length,
                itemBuilder: (c, i) {
                  final x = w[i];
                  return ListTile(
                      title: Text(x.display,
                          textDirection: ui.TextDirection.ltr,
                          style: TextStyle(
                              color: wordColor(x),
                              fontWeight: FontWeight.bold)),
                      subtitle: Text('${x.persian} • ${x.english}'),
                      trailing: IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: () => playWord(x)));
                }))
      ]));
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsPage> {
  bool auto = true, online = false;
  String time = '20:00',
      course = 'Starten Wir',
      book = 'Starten Wir A1',
      level = 'A1',
      message = '';
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
      time = p.getString('reminder') ?? '20:00';
      course = p.getString('course') ?? 'Starten Wir';
      book = p.getString('book') ?? 'Starten Wir A1';
      level = p.getString('level') ?? 'A1';
    });
  }

  Future<void> boolSet(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, v);
    setState(() => message = 'ذخیره شد');
  }

  Future<void> textSet(String k, String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(k, v);
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
    }
  }

  Future<void> backup() async {
    final path = await FilePicker.platform.saveFile(
        fileName: 'starten_wir_a1_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json']);
    if (path == null) return;
    final rows = await VocabularyDb.instance.backupRows();
    await File(path).writeAsString(jsonEncode({
      'format': 'starten-wir-a1-progress-v1',
      'createdAt': DateTime.now().toIso8601String(),
      'course': course,
      'book': book,
      'level': level,
      'words': rows
    }));
    setState(() => message = 'بکاپ ذخیره شد');
  }

  Future<void> restore() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) return;
    final data =
        jsonDecode(await File(result.files.single.path!).readAsString());
    await VocabularyDb.instance.restoreRows(data['words'] as List);
    setState(() => message = 'بازیابی پیشرفت انجام شد');
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(children: [
        const Header('انتخاب دوره'),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DropdownButtonFormField<String>(
                value: course,
                decoration: const InputDecoration(labelText: 'کورس'),
                items: const [
                  DropdownMenuItem(
                      value: 'Starten Wir', child: Text('Starten Wir'))
                ],
                onChanged: (v) {
                  if (v != null) {
                    course = v;
                    textSet('course', v);
                  }
                })),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DropdownButtonFormField<String>(
                value: book,
                decoration: const InputDecoration(labelText: 'کتاب'),
                items: const [
                  DropdownMenuItem(
                      value: 'Starten Wir A1', child: Text('Starten Wir A1'))
                ],
                onChanged: (v) {
                  if (v != null) {
                    book = v;
                    textSet('book', v);
                  }
                })),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DropdownButtonFormField<String>(
                value: level,
                decoration: const InputDecoration(labelText: 'سطح'),
                items: const [DropdownMenuItem(value: 'A1', child: Text('A1'))],
                onChanged: (v) {
                  if (v != null) {
                    level = v;
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
            subtitle:
                const Text('در صورت نبود اینترنت، تلفظ آفلاین استفاده می‌شود'),
            value: online,
            onChanged: (v) => boolSet('onlineAudio', v)),
        ListTile(
            title: const Text('زمان یادآوری مرور'),
            subtitle: Text(time),
            trailing: const Icon(Icons.notifications_active),
            onTap: pick),
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
        if (message.isNotEmpty)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)))
      ]));
}
