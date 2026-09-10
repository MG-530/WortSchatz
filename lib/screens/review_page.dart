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

  /// Box 0 (Leitner entry, enrolled via "add to Leitner") words are
  /// ALWAYS due — newly added words can be reviewed immediately, and the
  /// first real review promotes them to box 1.
  bool due(Word w) =>
      w.box == 0 ||
      w.nextReview == null ||
      !w.nextReview!.isAfter(DateTime.now());

  /// Due words actually enrolled in Leitner (boxes 1–5). This is what the
  /// Leitner box cards and "review ready" cover — box 0 has its own
  /// dedicated practice button below.
  bool dueEnrolled(Word w) => w.box > 0 && due(w);
  int total(int b) => all.where((w) => w.box == b).length;
  int ready(int b) => all.where((w) => w.box == b && due(w)).length;
  int get newCount => all.where((w) => w.box == 0).length;
  int get dueEnrolledCount => all.where(dueEnrolled).length;
  bool get hasDue => dueEnrolledCount > 0;

  /// Max words per "review all" session — reviewing hundreds of due
  /// words at once is neither usable nor useful for retention.
  static const int maxReviewAll = 30;

  String _sheetTitle(int b) => b < 0
      ? 'مرور همهٔ واژه‌ها'
      : b == 0
          ? 'تمرین واژه‌های جدید'
          : 'مرور باکس $b';
  String _sessionTitle(int b) => b < 0
      ? 'مرور آماده'
      : b == 0
          ? 'تمرین جدید'
          : 'مرور باکس $b';
  String _writingTitle(int b) =>
      'نوشتاری — ${b < 0 ? 'همه' : b == 0 ? 'جدید' : 'باکس $b'}';

  /// Push a session and reload counts when it pops, so grading is
  /// immediately visible (no stale box counts).
  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      if (mounted) load();
    });
  }

  void choose(int b) {
    // b < 0: "review ready" — enrolled due words only, capped.
    // b == 0: new-words review — box 0 entry words, capped.
    // b >= 1: single-box review with a "later" pile.
    final List<Word> readyWords;
    final List<Word> later;
    if (b < 0) {
      readyWords = all.where(dueEnrolled).take(maxReviewAll).toList();
      later = const [];
    } else if (b == 0) {
      readyWords = all.where((w) => w.box == 0).take(maxReviewAll).toList();
      later = const [];
    } else {
      final selected = all.where((w) => w.box == b).toList();
      readyWords = selected.where(due).toList();
      later = selected.where((w) => !due(w)).toList();
    }
    // Never open a session with zero ready words — WritingReview crashes
    // on empty lists (RangeError in initState) and an empty normal
    // session is useless anyway.
    if (readyWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('واژه‌ای آماده مرور نیست')));
      return;
    }
    var reverseMode = false;
    showModalBottomSheet(
        context: context,
        builder: (sheet) => StatefulBuilder(
            builder: (c, setSheet) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_sheetTitle(b),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  if (b < 0 && dueEnrolledCount > readyWords.length)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                            '$dueEnrolledCount واژه آماده است؛ این نوبت ${readyWords.length} تای اول مرور می‌شود',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey))),
                  SwitchListTile(
                      title: const Text('جهت معکوس (فارسی ← آلمانی)'),
                      subtitle: const Text('سؤال فارسی، جواب آلمانی'),
                      value: reverseMode,
                      onChanged: (v) => setSheet(() => reverseMode = v)),
                  ListTile(
                      leading: const Icon(Icons.style),
                      title: const Text('مرور عادی'),
                      subtitle: Text('${readyWords.length} واژه آماده مرور'),
                      onTap: () {
                        Navigator.pop(sheet);
                        _open(ReviewSession(
                            words: readyWords,
                            title: reverseMode
                                ? '${_sessionTitle(b)} (معکوس)'
                                : _sessionTitle(b),
                            extra: later,
                            reverseMode: reverseMode));
                      }),
                  ListTile(
                      leading: const Icon(Icons.keyboard),
                      title: const Text('مرور نوشتاری'),
                      subtitle: Text('${readyWords.length} واژه آماده نوشتاری'),
                      onTap: () {
                        Navigator.pop(sheet);
                        _open(WritingReviewSession(
                            words: readyWords, title: _writingTitle(b)));
                      })
                ]))));
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
                decoration: const InputDecoration(labelText: 'سطح'),
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
              // Only enrolled boxes (1–5) live here. Box 0 is the
              // not-in-Leitner pool with its own practice button below,
              // so a fresh install or a reset shows a truly empty Leitner.
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
                onPressed: !hasDue ? null : () => choose(-1),
                icon: const Icon(Icons.play_arrow),
                label: const Text('مرور آماده'))),
        const SizedBox(height: 8),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
                onPressed: newCount == 0 ? null : () => choose(0),
                icon: const Icon(Icons.fiber_new),
                label: Text('تمرین واژه‌های جدید ($newCount واژه)'))),
        const SizedBox(height: 8)
      ]));
}
