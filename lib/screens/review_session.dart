import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../services/database_service.dart';

class ReviewSession extends StatefulWidget {
  final List<Word> words;
  final String title;
  final List<Word> extra;
  const ReviewSession(
      {required this.words,
      required this.title,
      this.extra = const [],
      super.key});
  @override
  State<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<ReviewSession> {
  int i = 0;
  bool show = false;

  @override
  Widget build(BuildContext c) {
    if (widget.words.isEmpty)
      return const Scaffold(
          body: Center(child: Text('واژهٔ آماده‌ای برای مرور نیست')));
    final w = widget.words[i];
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('کارت ${i + 1} از ${widget.words.length}'),
              Expanded(
                  child: GestureDetector(
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
                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(w.display,
                                        textDirection: ui.TextDirection.ltr,
                                        style: TextStyle(
                                            fontSize: 46,
                                            fontWeight: FontWeight.bold,
                                            color: wordColor(w)))),
                                if (show) ...[
                                  const SizedBox(height: 20),
                                  Text(w.persian,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                  Text(w.english)
                                ]
                              ])))))),
              if (!show)
                FilledButton(
                    onPressed: () => setState(() => show = true),
                    child: const Text('نمایش پاسخ'))
              else
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                          onPressed: () => grade(false),
                          child: const Text('بلد نبودم')),
                      FilledButton(
                          onPressed: () => grade(true),
                          child: const Text('بلد بودم'))
                    ])
            ])));
  }

  Future<void> grade(bool ok) async {
    await VocabularyDb.instance.grade(widget.words[i], ok);
    if (i + 1 >= widget.words.length) {
      if (widget.extra.isNotEmpty && mounted) {
        final go = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
                    title: const Text('مرور آماده تمام شد'),
                    content: const Text(
                        'واژه‌های آماده‌نشده را هم مرور می‌کنی؟ در این حالت باکس‌ها تغییر نمی‌کنند.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('خیر')),
                      FilledButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('بله'))
                    ]));
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
    } else
      setState(() {
        i++;
        show = false;
      });
  }
}
