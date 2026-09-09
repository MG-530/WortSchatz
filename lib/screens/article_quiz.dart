import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/streak_service.dart';
import '../widgets/header.dart';

/// Multiple-choice article quiz (der/die/das).
/// Pure practice: boxes are never touched; attempts feed the streak.
class ArticleQuizPage extends StatefulWidget {
  final String level;

  /// When set, quiz only words of this lesson (1..12); otherwise the
  /// whole level.
  final int? lesson;
  const ArticleQuizPage({required this.level, this.lesson, super.key});
  @override
  State<ArticleQuizPage> createState() => _ArticleQuizState();
}

class _ArticleQuizState extends State<ArticleQuizPage> {
  static const int perSession = 20;
  static const options = ['der', 'die', 'das'];

  List<Word> words = [];
  int idx = 0;
  String? picked;
  bool locked = false;
  bool finished = false;
  int correct = 0;
  int answered = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    var all = await VocabularyDb.instance.all(level: widget.level);
    if (widget.lesson != null) {
      all = all.where((w) => w.lessons.contains(widget.lesson)).toList();
    }
    all.shuffle();
    words =
        all.where((w) => options.contains(w.article)).take(perSession).toList();
    if (mounted) setState(() => loaded = true);
  }

  String get scopeLabel => widget.lesson == null
      ? 'کل سطح ${widget.level}'
      : 'درس ${Word.lessonCode(widget.level, widget.lesson!)}';

  @override
  void dispose() {
    if (answered >= StreakService.minAnswersForStreak) {
      StreakService.recordStudySession(wordsStudied: answered);
    }
    super.dispose();
  }

  Word? get x => words.isEmpty || idx >= words.length ? null : words[idx];

  void pick(String a) {
    if (locked || x == null) return;
    final ok = a == x!.article;
    setState(() {
      locked = true;
      picked = a;
      answered++;
      if (ok) correct++;
    });
    // Longer pause so the animated reveal can be enjoyed.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (idx + 1 >= words.length) {
        setState(() => finished = true);
      } else {
        setState(() {
          idx++;
          locked = false;
          picked = null;
        });
      }
    });
  }

  void retry() {
    words.shuffle();
    setState(() {
      idx = 0;
      locked = false;
      picked = null;
      finished = false;
      correct = 0;
      answered = 0;
    });
  }

  Color? optionColor(String a) {
    if (!locked) return null;
    if (a == x!.article) return Colors.green;
    if (a == picked) return Colors.red;
    return null;
  }

  bool get wasCorrect => locked && picked == x!.article;

  /// Animated verdict banner: pops in on every answer and always names
  /// the correct article.
  Widget verdictBanner() => AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: !locked
          ? SizedBox.shrink(key: ValueKey('hide$idx'))
          : Container(
              key: ValueKey('show$idx'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: (wasCorrect ? Colors.green : Colors.red)
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12)),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(wasCorrect ? Icons.check_circle : Icons.cancel,
                    color: wasCorrect ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(
                    wasCorrect
                        ? 'درست است! آفرین'
                        : 'اشتباه شد — جواب درست: ${x!.article}',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: wasCorrect
                            ? Colors.green.shade800
                            : Colors.red.shade800))
              ])));

  @override
  Widget build(BuildContext c) {
    final q = x;
    return Scaffold(
        appBar: AppBar(title: Text('کوئیز آرتیکل — $scopeLabel')),
        body: SafeArea(
            child: !loaded
                ? const Center(child: CircularProgressIndicator())
                : words.isEmpty
                    ? const Center(child: Text('واژه‌ای با ارتیکل یافت نشد'))
                    : finished
                        ? Center(
                            child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('$correct از ${words.length} درست',
                                          style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 8),
                                      Text(
                                          correct == words.length
                                              ? 'عالی! همه ارتیکل‌ها درست بود'
                                              : correct * 2 >= words.length
                                                  ? 'خوب پیش می‌روی!'
                                                  : 'با مرور بیشتر بهتر می‌شود',
                                          style: const TextStyle(
                                              color: Colors.grey)),
                                      const SizedBox(height: 24),
                                      FilledButton.icon(
                                          onPressed: retry,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('دوباره')),
                                      const SizedBox(height: 8),
                                      OutlinedButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('پایان'))
                                    ])))
                        : ListView(children: [
                            Header('آرتیکل درست را انتخاب کن ($scopeLabel)',
                                subtitle:
                                    'der (مذکر) • die (مونث) • das (خنثی)'),
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: LinearProgressIndicator(
                                    value: (idx + 1) / words.length)),
                            Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(children: [
                                  Text('سؤال ${idx + 1} از ${words.length}',
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Text(q!.german,
                                      textDirection: ui.TextDirection.ltr,
                                      style: const TextStyle(
                                          fontSize: 44,
                                          fontWeight: FontWeight.w800)),
                                  Text(q.persian,
                                      style: const TextStyle(
                                          fontSize: 18, color: Colors.grey)),
                                  const SizedBox(height: 24),
                                  for (final a in options)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        // Pop animation on the tapped option.
                                        child: AnimatedScale(
                                            scale: locked && a == picked
                                                ? 1.05
                                                : 1.0,
                                            duration: const Duration(
                                                milliseconds: 200),
                                            child: SizedBox(
                                                width: double.infinity,
                                                child: FilledButton.tonal(
                                                    style: FilledButton.styleFrom(
                                                        backgroundColor:
                                                            optionColor(a),
                                                        padding: const EdgeInsets.symmetric(
                                                            vertical: 16)),
                                                    onPressed: locked
                                                        ? null
                                                        : () => pick(a),
                                                    child: Text(a,
                                                        textDirection: ui
                                                            .TextDirection.ltr,
                                                        style: const TextStyle(
                                                            fontSize: 24,
                                                            fontWeight:
                                                                FontWeight.bold)))))),
                                  const SizedBox(height: 12),
                                  verdictBanner(),
                                  const SizedBox(height: 8),
                                  Text('امتیاز: $correct',
                                      style:
                                          const TextStyle(color: Colors.grey))
                                ]))
                          ])));
  }
}
