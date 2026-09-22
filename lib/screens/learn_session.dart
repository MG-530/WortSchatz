import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../helpers/labels.dart';
import '../services/audio_service.dart';
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

  /// Distinct cards the user actually viewed in this session.
  /// Study-only page: no grading here. Leaving counts toward the streak
  /// only when real studying happened (not a brief open-and-close).
  final Set<int> _seen = {0};

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    auto = await AppSettings.autoPlay;
    online = await AppSettings.onlineAudio;
    if (auto && widget.words.isNotEmpty) {
      playWord(widget.words[0], online: online);
    }
    if (mounted) setState(() {});
  }

  void move(int delta) {
    if (widget.words.isEmpty) return;
    setState(() {
      index = (index + delta + widget.words.length) % widget.words.length;
      revealed = false;
      _seen.add(index);
    });
    if (auto) playWord(widget.words[index], online: online);
  }

  @override
  void dispose() {
    // Study effort (distinct cards viewed), not grading, feeds the streak.
    if (widget.words.isNotEmpty &&
        _seen.length >=
            StreakService.minAnswersForStreak.clamp(1, widget.words.length)) {
      StreakService.recordStudySession(wordsStudied: _seen.length);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (widget.words.isEmpty) {
      return const Scaffold(body: Center(child: Text('این درس واژه‌ای ندارد')));
    }
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
                        if (d.primaryVelocity != null) {
                          move(d.primaryVelocity! > 0 ? -1 : 1);
                        }
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
                                            backgroundColor: wordColor(w)
                                                .withValues(alpha: .14)),
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
                    onPressed: () => move(1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('بعدی')),
                IconButton.filledTonal(
                    onPressed: () => playWord(w, online: online),
                    icon: const Icon(Icons.volume_up)),
                FilledButton.icon(
                    onPressed: () => move(-1),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('قبلی'))
              ])
            ])));
  }
}
