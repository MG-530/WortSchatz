import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../services/database_service.dart';
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
    all = await VocabularyDb.instance.all(level: level);
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
