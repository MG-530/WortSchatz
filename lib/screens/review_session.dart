import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/streak_service.dart';
import 'writing_review.dart';

class ReviewSession extends StatefulWidget {
  final List<Word> words;
  final String title;
  final List<Word> extra;

  /// When true, the question side shows Persian (recall German) instead
  /// of German (recall meaning). Grading and streak logic are unchanged.
  final bool reverseMode;

  /// When false, answers only flip through the cards (no Leitner
  /// grading) — used for the meaning pass of sequential mode, where
  /// the follow-up writing check does the real grading.
  final bool gradeOnAnswer;
  const ReviewSession(
      {required this.words,
      required this.title,
      this.extra = const [],
      this.reverseMode = false,
      this.gradeOnAnswer = true,
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

  /// Whether the current card was graded. Leaving the card (forward,
  /// swipe or back) is locked until the user answers — no skipping.
  bool _graded = false;

  /// Plural forms for this session's nouns (one batch query).
  Map<String, String> plurals = {};

  /// Ids of session words marked as difficult.
  Set<int> starred = {};

  /// Leitner audio mode (0 = silent, 1 = front + back, 2 = back only).
  int _audioMode = 0;

  @override
  void initState() {
    super.initState();
    show = false;
    VocabularyDb.instance
        .pluralsFor(widget.words.map((w) => w.german).toList())
        .then((m) {
      if (mounted) setState(() => plurals = m);
    });
    VocabularyDb.instance
        .starredIn(widget.words.map((w) => w.id).toList())
        .then((ids) {
      if (mounted) setState(() => starred = ids);
    });
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    _audioMode = await AppSettings.leitnerAudio;
    if (_audioMode == 1 && mounted && widget.words.isNotEmpty) {
      _playFront();
    }
  }

  void _playFront() {
    if (widget.words.isEmpty) return;
    // Bare word only: a spoken article would leak the gender hint.
    playWord(widget.words[i], withArticle: false);
  }

  void _playBack() {
    if (widget.words.isEmpty) return;
    // Full form; the article follows the articleTts setting.
    playWord(widget.words[i]);
  }

  Future<void> _toggleStar() async {
    if (widget.words.isEmpty) return;
    final id = widget.words[i].id;
    await VocabularyDb.instance.toggleStar(id);
    if (!mounted) return;
    setState(() {
      if (starred.contains(id)) {
        starred.remove(id);
      } else {
        starred.add(id);
      }
    });
  }

  void _reveal() {
    final willShow = !show;
    setState(() => show = willShow);
    if (willShow && _audioMode >= 1) _playBack();
  }

  void _moveTo(int next) {
    setState(() {
      i = next;
      show = false;
      _graded = false;
    });
    if (_audioMode == 1) _playFront();
  }

  void _denySkip() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
          content: Text('اول بگو بلدی یا نه، بعد برو کارت بعدی')));
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
    if (widget.words.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('واژه ای اماده برای مرور نیست')));
    }
    final w = widget.words[i];
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          IconButton(
              tooltip: 'سخت',
              icon:
                  Icon(starred.contains(w.id) ? Icons.star : Icons.star_border),
              onPressed: _toggleStar)
        ]),
        body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('کارت ${i + 1} از ${widget.words.length}'),
              Expanded(
                  child: GestureDetector(
                      onTap: _reveal,
                      onHorizontalDragEnd: (d) {
                        if (d.primaryVelocity == null) return;
                        if (!_graded) {
                          _denySkip();
                          return;
                        }
                        _moveTo((i +
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
              // Grade buttons sit right under the card (away from the
              // system back gesture) and appear only after reveal.
              if (show)
                Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: () => _handleAnswer(true),
                          icon: const Icon(Icons.check),
                          label: const Text('بلد بودم'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: () => _handleAnswer(false),
                          icon: const Icon(Icons.close),
                          label: const Text('بلد نبودم')))
                ])
              else
                const Text('برای دیدن جواب، کارت را لمس کن',
                    style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        // Back never grades — it only revisits the
                        // previous card. Meaningless for 1-word sessions.
                        // Locked until the current card is graded.
                        onPressed: widget.words.length <= 1 || !_graded
                            ? null
                            : _goBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('قبلی')))
              ])
            ])));
  }

  /// Go to the previous card without grading it.
  void _goBack() {
    if (widget.words.isEmpty) return;
    _moveTo((i - 1 + widget.words.length) % widget.words.length);
  }

  void _handleAnswer(bool known) {
    if (widget.gradeOnAnswer) {
      VocabularyDb.instance.grade(widget.words[i], known);
    }
    StreakService.recordAnswer(correct: known);
    _answered++;
    _graded = true;
    if (i + 1 < widget.words.length) {
      _moveTo(i + 1);
    } else {
      _finishSession();
    }
  }

  /// Called only when the user answers the LAST card — i.e. actually
  /// finishes the session — never on mere navigation away.
  Future<void> _finishSession() async {
    _streakRecorded = true;
    await StreakService.recordStudySession(wordsStudied: _answered);
    if (!widget.gradeOnAnswer && mounted) {
      // Sequential mode: the meaning pass did not grade, so hand the
      // same words to the writing check, which does the real grading.
      // (The not-due extra pile is skipped in this mode.)
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => WritingReviewSession(
                  words: widget.words, title: 'نوشتاری — ${widget.title}')));
      return;
    }
    if (widget.extra.isNotEmpty && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => const AlertDialog(
            title: Text('مرور آمده تمام شد'),
            content: Text(
                'واژه‌های آماده‌نشده را هم مرور می‌کنی؟ در این حالت باکس‌ها تغییر نمی‌شود.')),
      );
      if (go == true && mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => ReviewSession(
                    words: widget.extra,
                    title: 'مرور غیرآماده',
                    extra: const [],
                    reverseMode: widget.reverseMode)));
      } else if (mounted) {
        Navigator.pop(context);
      }
    } else if (mounted) {
      Navigator.pop(context);
    }
  }
}
