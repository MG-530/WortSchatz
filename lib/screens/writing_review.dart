import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/streak_service.dart';

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
  List<String> letters = [];

  /// Graded answers in this session + whether the streak was recorded
  /// at natural finish (avoids double counting on pop).
  int _graded = 0;
  bool _streakRecorded = false;

  Word get w => widget.words[i];

  @override
  void initState() {
    super.initState();
    // Guarded: an empty word list must show the empty-state message in
    // build() instead of crashing here on words[0].
    if (widget.words.isNotEmpty) lettersForWord();
  }

  @override
  void dispose() {
    // Early exit: count the session only when real work was done.
    if (!_streakRecorded && _graded >= StreakService.minAnswersForStreak) {
      StreakService.recordStudySession(wordsStudied: _graded);
    }
    input.dispose();
    super.dispose();
  }

  void lettersForWord() {
    letters = w.german.replaceAll(' ', '').split('')..shuffle();
  }

  Future<void> listen() async {
    final withArticle = await AppSettings.articleTts;
    await tts.setLanguage('de-DE');
    await tts.speak(spokenText(w, withArticle: withArticle));
  }

  void addLetter(String ch) {
    if (checked) return;
    setState(() {
      typed += ch;
      // Consume the used hint letter so it disappears from the pool.
      letters.remove(ch);
      input.text = typed;
      input.selection = TextSelection.collapsed(offset: typed.length);
    });
  }

  /// Delete the last typed character and return it to the hint pool.
  void backspace() {
    if (checked || typed.isEmpty) return;
    setState(() {
      final ch = typed[typed.length - 1];
      typed = typed.substring(0, typed.length - 1);
      letters.add(ch);
      input.text = typed;
      input.selection = TextSelection.collapsed(offset: typed.length);
    });
  }

  Future<void> submit() async {
    if (checked) return;
    // Compare the actual field content (not the chip-built buffer):
    // keyboard typing never updated `typed`, so every typed answer
    // used to be graded wrong.
    final ok = w.matchesSpelling(input.text);
    await VocabularyDb.instance.grade(w, ok);
    _graded++;
    if (mounted) {
      setState(() {
        checked = true;
        correct = ok;
      });
      _autoNext();
    }
  }

  Future<void> unknown() async {
    if (checked) return;
    await VocabularyDb.instance.grade(w, false);
    _graded++;
    if (mounted) {
      setState(() {
        checked = true;
        correct = false;
      });
      _autoNext();
    }
  }

  /// Show the verdict briefly, then move on automatically.
  void _autoNext() {
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted && checked) next();
    });
  }

  void next() {
    if (i + 1 >= widget.words.length) {
      // Natural finish of the session → record the streak.
      _streakRecorded = true;
      StreakService.recordStudySession(wordsStudied: _graded);
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
    if (widget.words.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('واژه ای اماده برای مرور نیست')));
    }
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
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: input,
                        autofocus: true,
                        enabled: !checked,
                        textDirection: ui.TextDirection.ltr,
                        decoration: const InputDecoration(
                            labelText: 'آلمانی را تایپ کن',
                            border: OutlineInputBorder()))),
                IconButton(
                    tooltip: 'پاک کردن حرف آخر',
                    onPressed: checked || typed.isEmpty ? null : backspace,
                    icon: const Icon(Icons.backspace_outlined))
              ]),
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
                AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Container(
                        key: ValueKey('verdict$i$correct'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            color: (correct ? Colors.green : Colors.red)
                                .withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(correct ? Icons.check_circle : Icons.cancel,
                                  color: correct ? Colors.green : Colors.red),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(
                                      correct
                                          ? 'درست است! آفرین'
                                          : 'اشتباه شد — جواب: ${w.display}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: correct
                                              ? Colors.green.shade800
                                              : Colors.red.shade800)))
                            ])))
            ])));
  }
}
