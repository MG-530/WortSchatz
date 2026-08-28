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
  Widget build(BuildContext c) {
    return SafeArea(
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(children: [
          const Header('واژه‌ها', subtitle: 'جست‌وجوی همهٔ واژه‌های کتاب'),
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
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: w.length,
              itemBuilder: (c, i) {
                final x = w[i];
                return ListTile(
                  title: Text(x.display,
                      textDirection: ui.TextDirection.ltr,
                      style: TextStyle(
                          color: wordColor(x), fontWeight: FontWeight.bold)),
                  subtitle: Text('${x.persian} • ${x.english}'),
                  trailing: IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => playWord(x)),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
