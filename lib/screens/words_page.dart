import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final searchCtl = TextEditingController();

  static const List<String> wordTypes = [
    'all',
    'noun',
    'verb',
    'adjective',
    'phrase',
    'other'
  ];

  /// Debounces keystrokes so fast typing issues one query, not one per
  /// character (each query hits SQLite).
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Restore last session's filters (they persist until the app is
  /// closed and beyond — SharedPreferences survives restarts too).
  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      level = p.getString('wordsLevel') ?? 'all';
      lesson = p.getInt('wordsLesson') ?? 0;
      wordType = p.getString('wordsType') ?? 'all';
      q = p.getString('wordsQuery') ?? '';
      searchCtl.text = q;
    });
    load();
  }

  Future<void> _saveFilters() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('wordsLevel', level);
    await p.setInt('wordsLesson', lesson);
    await p.setString('wordsType', wordType);
    await p.setString('wordsQuery', q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchCtl.dispose();
    super.dispose();
  }

  void onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      q = v;
      _saveFilters();
      load();
    });
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
                child: SingleChildScrollView(
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
                      FutureBuilder<String?>(
                          future: VocabularyDb.instance.pluralFor(x.german),
                          builder: (c, snap) {
                            if (snap.connectionState != ConnectionState.done ||
                                snap.data == null) {
                              return const SizedBox.shrink();
                            }
                            return Text('جمع: ${snap.data}',
                                textDirection: ui.TextDirection.ltr,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13));
                          }),
                      if (x.pronunciation.isNotEmpty)
                        Text('/${x.pronunciation}/',
                            textDirection: ui.TextDirection.ltr,
                            style: const TextStyle(color: Colors.grey)),
                      FutureBuilder<List<Map<String, String>>>(
                          future: VocabularyDb.instance.examplesFor(x.german),
                          builder: (c, snap) {
                            if (snap.connectionState != ConnectionState.done ||
                                snap.data == null ||
                                snap.data!.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('مثال‌ها',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      for (final e in snap.data!)
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(e['de'] ?? '',
                                                      textDirection:
                                                          ui.TextDirection.ltr,
                                                      style: const TextStyle(
                                                          fontSize: 15)),
                                                  Text(e['fa'] ?? '',
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey)),
                                                ])),
                                    ]));
                          }),
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
                    ])))));
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
                    controller: searchCtl,
                    textDirection: ui.TextDirection.ltr,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'German / Persian / English',
                        border: OutlineInputBorder()),
                    onChanged: onQueryChanged)),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('wlevel-$level'),
                    initialValue: level,
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
                        _saveFilters();
                        load();
                      }
                    },
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey('wlesson-$lesson'),
                    initialValue: lesson,
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
                        _saveFilters();
                        load();
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('wtype-$wordType'),
                    initialValue: wordType,
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
                        _saveFilters();
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
                                  Text('${x.persian} ${x.english}',
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
