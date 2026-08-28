import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../widgets/header.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});
  @override
  State<PracticePage> createState() => _PracticeState();
}

class _PracticeState extends State<PracticePage> {
  List<Word> words = [];
  int mode = 0;
  String writingMode = 'listen';
  final answer = TextEditingController();
  String feedback = '';
  DateTime? started;
  final tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    words = await VocabularyDb.instance.all();
    words.shuffle();
    if (mounted) setState(() {});
  }

  Word? get x => words.isEmpty ? null : words.first;

  Future<void> listen() async {
    if (x != null) {
      await tts.setLanguage('de-DE');
      await tts.speak(x!.german);
    }
  }

  void check(String correct) {
    final ok = answer.text.trim().toLowerCase() == correct.trim().toLowerCase();
    setState(() => feedback = ok ? 'درست است' : 'اشتباه است؛ دوباره تلاش کن');
  }

  @override
  Widget build(BuildContext c) {
    final q = x;
    if (q == null) return const Center(child: CircularProgressIndicator());
    return SafeArea(
        child: ListView(children: [
      const Header('تمرین', subtitle: 'ترجمه و رایتینگ فعال'),
      Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('ترجمه')),
                ButtonSegment(value: 1, label: Text('رایتینگ'))
              ],
              selected: {mode},
              onSelectionChanged: (s) {
                answer.clear();
                setState(() => mode = s.first);
              })),
      Padding(
          padding: const EdgeInsets.all(20),
          child: mode == 0
              ? Column(children: [
                  Text(q.persian,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  if (started != null)
                    Text(
                        'زمان: ${DateTime.now().difference(started!).inSeconds} ثانیه'),
                  FilledButton(
                      onPressed: () => setState(() => started = DateTime.now()),
                      child: const Text('شروع تایمر')),
                  TextField(
                      controller: answer,
                      textDirection: ui.TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'معنی را به آلمانی بنویس',
                          border: OutlineInputBorder())),
                  FilledButton(
                      onPressed: () => check(q.german),
                      child: const Text('بررسی')),
                  if (feedback.isNotEmpty)
                    Text(feedback,
                        style: TextStyle(
                            color: feedback == 'درست است'
                                ? Colors.green
                                : Colors.red))
                ])
              : Column(children: [
                  DropdownButton<String>(
                      value: writingMode,
                      items: const [
                        DropdownMenuItem(
                            value: 'listen',
                            child: Text('شنیدن و فقط تایپ خود لغت')),
                        DropdownMenuItem(
                            value: 'scramble',
                            child: Text('ساختن از حروف به‌هم‌ریخته'))
                      ],
                      onChanged: (v) {
                        answer.clear();
                        setState(() => writingMode = v ?? 'listen');
                      }),
                  if (writingMode == 'listen') ...[
                    IconButton.filled(
                        onPressed: listen, icon: const Icon(Icons.volume_up)),
                    TextField(
                        controller: answer,
                        autofocus: true,
                        textDirection: ui.TextDirection.ltr,
                        decoration: const InputDecoration(
                            labelText: 'خود لغت آلمانی را تایپ کن',
                            border: OutlineInputBorder()))
                  ] else ...[
                    Wrap(spacing: 8, children: [
                      for (final ch
                          in (q.german.replaceAll(' ', '').split('')
                            ..shuffle()))
                        ActionChip(
                            label: Text(ch),
                            onPressed: () => setState(() => answer.text += ch))
                    ]),
                    TextField(
                        controller: answer,
                        textDirection: ui.TextDirection.ltr,
                        decoration: const InputDecoration(
                            labelText: 'لغت ساخته‌شده',
                            border: OutlineInputBorder()))
                  ],
                  FilledButton(
                      onPressed: () => check(q.german),
                      child: const Text('بررسی')),
                  if (feedback.isNotEmpty)
                    Text(feedback,
                        style: TextStyle(
                            color: feedback == 'درست است'
                                ? Colors.green
                                : Colors.red))
                ]))
    ]));
  }
}
