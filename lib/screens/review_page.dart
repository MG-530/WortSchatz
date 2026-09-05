import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/word.dart';
import 'review_session.dart';
import 'writing_review.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});
  @override
  State<ReviewPage> createState() => _ReviewState();
}

class _ReviewState extends State<ReviewPage> {
  List<Word> all = [];
  String level = 'A1';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    level = await AppSettings.level;
    all = await VocabularyDb.instance.all(level: level);
    if (mounted) setState(() {});
  }

  Future<void> changeLevel(String v) async {
    await AppSettings.setString('level', v);
    setState(() => level = v);
    all = await VocabularyDb.instance.all(level: level);
    if (mounted) setState(() {});
  }

  /// Only words enrolled in Leitner (box >= 1) are reviewable here.
  /// Box 0 is the "not in Leitner yet" pool — it must be added via
  /// Lessons ("افزودن به لایتنر") or a first Learn tap, never reviewed
  /// directly, so a fresh install starts with an empty Leitner.
  bool due(Word w) =>
      w.box > 0 &&
      (w.nextReview == null || !w.nextReview!.isAfter(DateTime.now()));
  int total(int b) => all.where((w) => w.box == b).length;
  int ready(int b) => all.where((w) => w.box == b && due(w)).length;

  /// Max words per "review all" session — reviewing hundreds of due
  /// words at once is neither usable nor useful for retention.
  static const int maxReviewAll = 30;

  void choose(int b) {
    // For "review all", only due words are eligible and the session is
    // capped at [maxReviewAll]; there is no "later" pile in that mode
    // (title says "مرور آماده" — ready words only).
    final List<Word> readyWords;
    final List<Word> later;
    if (b < 0) {
      readyWords = all.where(due).take(maxReviewAll).toList();
      later = const [];
    } else {
      final selected = all.where((w) => w.box == b).toList();
      readyWords = selected.where(due).toList();
      later = selected.where((w) => !due(w)).toList();
    }
    showModalBottomSheet(
        context: context,
        builder: (sheet) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(b < 0 ? 'مرور همهٔ واژه‌ها' : 'مرور باکس $b',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              if (b < 0 && all.where(due).length > readyWords.length)
                Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                        '${all.where(due).length} واژه آماده است؛ این نوبت ${readyWords.length} تای اول مرور می‌شود',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey))),
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
                                title: 'نوشتاری — ${b < 0 ? 'همه' : 'باکس $b'}')));
                  })
            ])));
  }

  @override
  Widget build(BuildContext c) => SafeArea(
          child: ListView(children: [
        const Header('لایتنر',
            subtitle: 'فقط واژه‌های آماده، طبق زمان‌بندی مرور می‌شوند'),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: DropdownButtonFormField<String>(
                value: level,
                decoration:
                    const InputDecoration(labelText: 'سطح'),
                items: const [
                  DropdownMenuItem(value: 'A1', child: Text('A1')),
                  DropdownMenuItem(value: 'A2', child: Text('A2')),
                ],
                onChanged: (v) {
                  if (v != null && v != level) changeLevel(v);
                })),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (int b = 1; b <= 5; b++)
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
