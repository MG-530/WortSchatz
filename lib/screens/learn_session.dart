import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../helpers/labels.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/streak_service.dart';

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

  /// Number of cards the user actually graded in this session.
  /// The streak is recorded on leave ONLY when this reaches a meaningful
  /// threshold — briefly opening a lesson never counts.
  int _graded = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    auto = await AppSettings.autoPlay;
    online = await AppSettings.onlineAudio;
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
  void dispose() {
    if (_graded >= StreakService.minAnswersForStreak) {
      StreakService.recordStudySession(wordsStudied: _graded);
    }
    super.dispose();
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
                                                wordColor(w).withValues(alpha: .14)),
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
                    onPressed: () {
                      VocabularyDb.instance.grade(w, true);
                      _graded++;
                      move(1);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('بلد')),
                FilledButton.icon(
                    onPressed: () {
                      VocabularyDb.instance.grade(w, false);
                      _graded++;
                      move(1);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('بلد نبودم'))
              ])
            ])));
  }
}
