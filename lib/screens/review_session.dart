import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../services/database_service.dart';
import '../services/streak_service.dart';

class ReviewSession extends StatefulWidget {
  final List<Word> words;
  final String title;
  final List<Word> extra;

  /// When true, the question side shows Persian (recall German) instead
  /// of German (recall meaning). Grading and streak logic are unchanged.
  final bool reverseMode;
  const ReviewSession(
      {required this.words,
      required this.title,
      this.extra = const [],
      this.reverseMode = false,
      super.key});
  @override
  State<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<ReviewSession> {
  int i = 0;
  bool show = false;

  /// Graded answers in this session + whether the streak was already
  /// recorded at natural finish (prevents double counting when the
  /// extra-words session replaces this one).
  int _answered = 0;
  bool _streakRecorded = false;

  /// Plural forms for this session's nouns (one batch query).
  Map<String, String> plurals = {};

  @override
  void initState() {
    super.initState();
    show = false;
    VocabularyDb.instance
        .pluralsFor(widget.words.map((w) => w.german).toList())
        .then((m) {
      if (mounted) setState(() => plurals = m);
    });
  }

  @override
  void dispose() {
    // Session ended early (user navigated back): only count it when real
    // work was done, never for a brief visit.
    if (!_streakRecorded && _answered >= StreakService.minAnswersForStreak) {
      StreakService.recordStudySession(wordsStudied: _answered);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (widget.words.isEmpty)
      return const Scaffold(
          body: Center(child: Text('واژه ای اماده برای مرور نیست')));
    final w = widget.words[i];
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('کارت ${i + 1} از ${widget.words.length}'),
              Expanded(
                  child: GestureDetector(
                      onTap: () => setState(() => show = !show),
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
                                if (!widget.reverseMode)
                                  FittedBox(
                                      fit: BoxFit.scaleDown,
                                      // Question side: bare word, no article,
                                      // single neutral color (no gender hint).
                                      child: Text(w.german,
                                          textDirection: ui.TextDirection.ltr,
                                          style: const TextStyle(
                                              fontSize: 46,
                                              fontWeight: FontWeight.bold)))
                                else ...[
                                  Text(w.persian,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(w.english,
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.grey))
                                ],
                                if (show) ...[
                                  const SizedBox(height: 20),
                                  // Answer side: full form WITH article in gender color.
                                  FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(w.display,
                                          textDirection: ui.TextDirection.ltr,
                                          style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: wordColor(w)))),
                                  const SizedBox(height: 8),
                                  if (plurals[w.german] != null)
                                    Text('جمع: ${plurals[w.german]}',
                                        textDirection: ui.TextDirection.ltr,
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.grey)),
                                  if (!widget.reverseMode)
                                    Text(w.persian,
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold)),
                                  Text(w.english)
                                ]
                              ])))))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        // Back never grades — it only revisits the
                        // previous card. Meaningless for 1-word sessions.
                        onPressed: widget.words.length <= 1 ? null : _goBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('قبلی')))
              ]),
              // Both grade buttons are always visible — including on
              // the answer side — so "didn't know" is one tap away.
              FilledButton(
                  onPressed: () => _handleAnswer(false),
                  child: const Text('بلد نبودم')),
              FilledButton(
                  onPressed: () => _handleAnswer(true),
                  child: const Text('بلد بودم'))
            ])));
  }

  /// Go to the previous card without grading it.
  void _goBack() {
    if (widget.words.isEmpty) return;
    setState(() {
      i = (i - 1 + widget.words.length) % widget.words.length;
      show = false;
    });
  }

  void _handleAnswer(bool known) {
    VocabularyDb.instance.grade(widget.words[i], known);
    _answered++;
    if (i + 1 < widget.words.length) {
      setState(() {
        i++;
        show = false;
      });
    } else {
      _finishSession();
    }
  }

  /// Called only when the user grades the LAST card — i.e. actually
  /// finishes the session — never on mere navigation away.
  Future<void> _finishSession() async {
    _streakRecorded = true;
    await StreakService.recordStudySession(wordsStudied: _answered);
    if (widget.extra.isNotEmpty && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
            title: const Text('مرور آمده تمام شد'),
            content: const Text(
                'واژه‌های آماده‌نشده را هم مرور می‌کنی؟ در این حالت باکس‌ها تغییر نمی‌شود.')),
      );
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
  }
}
