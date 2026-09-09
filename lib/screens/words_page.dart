import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../services/database_service.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../helpers/labels.dart';
import '../services/audio_service.dart';
import 'conjugation_page.dart';

class WordsPage extends StatefulWidget {
  const WordsPage({super.key});
  @override
  State<WordsPage> createState() => _WordsState();
}

class _WordsState extends State<WordsPage> {
  List<Word> w = [];
  String q = '';
  String level = 'all';
  int lesson = 0;
  String wordType = 'all';

  static const List<String> wordTypes = [
    'all',
    'noun',
    'verb',
    'adjective',
    'phrase',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    w = await VocabularyDb.instance.all(
      level: level == 'all' ? null : level,
      lesson: lesson == 0 ? null : lesson,
      wordType: wordType == 'all' ? null : wordType,
      query: q,
    );
    if (mounted) setState(() {});
  }

  /// Word detail sheet: full info + pronunciation + conjugation button
  /// (only when tables exist for the word).
  void showDetail(Word x) {
    showModalBottomSheet(
        context: context,
        builder: (sheet) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(x.display,
                                textDirection: ui.TextDirection.ltr,
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: wordColor(x)))),
                        IconButton.filledTonal(
                            onPressed: () => playWord(x),
                            icon: const Icon(Icons.volume_up))
                      ]),
                      const SizedBox(height: 8),
                      Text(
                          '${x.level} • ${typeLabel(x)}${x.article.isNotEmpty ? ' • ${x.article}' : ''}',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(x.persian,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(x.english,
                          style: const TextStyle(color: Colors.grey)),
                      if (x.pronunciation.isNotEmpty)
                        Text('/${x.pronunciation}/',
                            textDirection: ui.TextDirection.ltr,
                            style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      FutureBuilder<Map<String, dynamic>?>(
                          future:
                              VocabularyDb.instance.conjugationFor(x.german),
                          builder: (c, snap) {
                            if (snap.connectionState != ConnectionState.done ||
                                snap.data == null) {
                              return const SizedBox.shrink();
                            }
                            final data = snap.data!;
                            return SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.pop(sheet);
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ConjugationPage(
                                                  verb: data['verb'] as String,
                                                  moods:
                                                      data['moods'] as List)));
                                    },
                                    icon: const Icon(Icons.table_chart),
                                    label: Text('صرف فعل ${data['verb']}')));
                          })
                    ]))));
  }

  @override
  Widget build(BuildContext c) => SafeArea(
      child: Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Column(children: [
            const Header('واژه‌ها', subtitle: 'جستجو و فیلتر واژگان'),
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
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  DropdownButtonFormField<String>(
                    value: level,
                    decoration: const InputDecoration(
                      labelText: 'سطح',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('همه')),
                      DropdownMenuItem(value: 'A1', child: Text('A1')),
                      DropdownMenuItem(value: 'A2', child: Text('A2')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        level = v;
                        load();
                      }
                    },
                  ),
                  DropdownButtonFormField<int>(
                    value: lesson,
                    decoration: const InputDecoration(
                      labelText: 'درس',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('همه')),
                      for (int i = 1; i <= 12; i++)
                        DropdownMenuItem(value: i, child: Text('درس $i')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        lesson = v;
                        load();
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: wordType,
                    decoration: const InputDecoration(
                      labelText: 'نوع',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isDense: true,
                    items: wordTypes
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t == 'all' ? 'همه' : t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        wordType = v;
                        load();
                      }
                    },
                  ),
                ])),
            Expanded(
                child: ListView.builder(
                    itemCount: w.length,
                    itemBuilder: (c, i) {
                      final x = w[i];
                      return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                              onTap: () => showDetail(x),
                              title: Text(x.display,
                                  textDirection: ui.TextDirection.ltr,
                                  style: TextStyle(
                                      color: wordColor(x),
                                      fontWeight: FontWeight.bold)),
                              subtitle: Row(
                                children: [
                                  const SizedBox(width: 4),
                                  Text(
                                      '${x.level} درس ${x.lessons.isEmpty ? '–' : x.lessons.reduce((a, b) => a < b ? a : b)} ${typeLabel(x)}',
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
