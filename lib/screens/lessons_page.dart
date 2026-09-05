import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/header.dart';
import '../services/database_service.dart';
import '../models/word.dart';
import 'learn_session.dart';

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});
  @override
  State<LessonsPage> createState() => _LessonsState();
}

class _LessonsState extends State<LessonsPage> {
  List<Word> w = [];
  String level = 'A1';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => level = p.getString('level') ?? 'A1');
    }
    w = await VocabularyDb.instance.all(level: level);
    if (mounted) setState(() {});
  }

  /// Only levels with bundled content can be selected. B1/B2 are shown
  /// disabled ("به‌زودی") so users can't switch to an empty level.
  static const availableLevels = ['A1', 'A2'];

  Future<void> changeLevel(String v) async {
    if (!availableLevels.contains(v)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('این سطح به‌زودی اضافه می‌شود')));
      }
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('level', v);
    setState(() => level = v);
    w = await VocabularyDb.instance.all(level: level);
    if (mounted) setState(() {});
  }

  int count(int l) => w.where((x) => x.lessons.contains(l)).length;

  Future<void> addScope(String title, {int? lesson, String? levelFilter}) async {
    // Load fresh data to ensure we have the latest box status
    final freshWords = await VocabularyDb.instance.all(level: levelFilter ?? level);
    
    final wordsToAdd = freshWords.where((x) {
      if (lesson != null && !x.lessons.contains(lesson)) return false;
      if (levelFilter != null && x.level != levelFilter) return false;
      return x.box == 0;
    }).toList();

    if (wordsToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('همه واژه‌ها قبلاً در لایتنر هستند')));
      return;
    }

    // New words enter box 1 scheduled for TOMORROW (box-1 interval = 1 day),
    // never "due right now". Scheduling them at DateTime.now() would make
    // the very first "I know it" tap promote them to box 2 on the same day.
    final tomorrow =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();
    final batch = VocabularyDb.instance.batch();
    for (final word in wordsToAdd) {
      batch.update('words', {'box': 1, 'next_review': tomorrow},
          where: 'id = ?', whereArgs: [word.id]);
    }
    await batch.commit(noResult: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${wordsToAdd.length} واژه از $title به لایتنر اضافه شد')));
      load();
    }
  }

  List<int> get lessonNumbers {
    final set = <int>{};
    for (final x in w) {
      set.addAll(x.lessons);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// A2 lessons are stored as 101..112 — display them as 1..12.
  int displayNum(int l) => l > 100 ? l - 100 : l;

  String get coverAsset => level == 'A2'
      ? 'assets/starten_wir_a2_cover.jpg'
      : 'assets/starten_wir_a1_cover.jpg';

  Widget bookHeader() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(coverAsset,
                key: ValueKey(coverAsset),
                width: 94,
                height: 132,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 94,
                    height: 132,
                    color: const Color(0xff102a43),
                    child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book,
                              color: Colors.white, size: 40),
                          SizedBox(height: 8),
                          Text('Starten Wir',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))
                        ])))),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Starten Wir $level',
              style:
                  const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const Text('Deutsch als Fremdsprache',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
              value: level,
              decoration: const InputDecoration(labelText: 'سطح'),
              items: const [
                DropdownMenuItem(value: 'A1', child: Text('A1 — فعال')),
                DropdownMenuItem(value: 'A2', child: Text('A2 — فعال')),
                DropdownMenuItem(
                    value: 'B1',
                    enabled: false,
                    child: Text('B1 — به‌زودی')),
                DropdownMenuItem(
                    value: 'B2',
                    enabled: false,
                    child: Text('B2 — به‌زودی'))
              ],
              onChanged: (v) {
                if (v != null && v != level) changeLevel(v);
              })
        ]))
      ]));

  Widget lessonRow(int l) {
    final d = displayNum(l);
    final code = Word.lessonCode(level, l);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Card(
            child: ListTile(
                leading: const Icon(Icons.chevron_right),
                title: Text('درس $code — Lektion $d',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${count(l)} واژه'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: 'افزودن به لایتنر',
                      icon: const Icon(Icons.add_task),
                      onPressed: () => addScope('درس $code', lesson: l, levelFilter: level)),
                  CircleAvatar(child: Text(code, style: const TextStyle(fontSize: 12)))
                ]),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LearnSession(
                            words: w
                                .where((x) =>
                                    x.lessons.contains(l) && x.level == level)
                                .toList(),
                            title: 'درس $code'))))));
  }

  @override
  Widget build(BuildContext c) {
    final lessons = lessonNumbers;
    return SafeArea(
        child: ListView(children: [
      bookHeader(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: FilledButton.icon(
              onPressed: w.isEmpty
                  ? null
                  : () => addScope('کل کتاب Starten Wir $level', levelFilter: level),
              icon: const Icon(Icons.add_task),
              label: Text('افزودن کل کتاب به لایتنر ($level)'))),
      const Header('درس‌ها',
          subtitle: 'درس را انتخاب کن و یادگیری را شروع کن'),
      if (lessons.isEmpty)
        const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('برای این سطح درسی یافت نشد'))),
      for (final l in lessons) lessonRow(l)
    ]));
  }
}
