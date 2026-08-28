import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../services/database_service.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../services/audio_service.dart';

class WordsPage extends StatefulWidget {
  const WordsPage({super.key});
  @override
  State<WordsPage> createState() => _WordsState();
}

class _WordsState extends State<WordsPage> {
  List<Word> w = [];
  String q = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    w = await VocabularyDb.instance.all(query: q);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => SafeArea(
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(children: [
          const Header('واژه‌ها', subtitle: 'Search all book words'),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                  textDirection: ui.TextDirection.ltr,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'German / Persian / English',
                      border: OutlineInputBorder()),
                  onChanged: (v) {
                    q = v;
                    load();
                  })),
          Expanded(
              child: ListView.builder(
                  itemCount: w.length,
                  itemBuilder: (c, i) {
                    final x = w[i];
                    return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                            title: Text(x.display,
                                textDirection: ui.TextDirection.ltr,
                                style: TextStyle(
                                    color: wordColor(x),
                                    fontWeight: FontWeight.bold)),
                            subtitle: Row(
                              children: [
                                const SizedBox(width: 4),
                                Text('Lesson ${_getLesson(x)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                const Spacer(),
                                Text(x.persian + ' ' + x.english,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            trailing: IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: () => playWord(x))));
                  })),
        ])));
}

int _getLesson(Word word) {
  // Find the lowest lesson number from the word's lessons list
  if (word.lessons.isEmpty) return 0;
  return word.lessons.reduce((value, element) => value < element ? value : element);
}