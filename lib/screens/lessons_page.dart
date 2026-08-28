import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../services/database_service.dart';
import '../models/word.dart';
import 'learn_session.dart';

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});
  @override
  State<LessonsPage> createState() => _LessonsState();
}

class _LessonsState extends State<LessonsPage> {
  List<Word> w = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    w = await VocabularyDb.instance.all();
    if (mounted) setState(() {});
  }

  int count(int l) => w.where((x) => x.lessons.contains(l)).length;

  @override
  Widget build(BuildContext c) => SafeArea(
      child: ListView(children: [
        const Header('درس‌ها', subtitle: 'هر درس را جداگانه انتخاب و یاد بگیر'),
        for (int l = 1; l <= 12; l++)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Card(
                  child: ListTile(
                      leading: const Icon(Icons.chevron_right),
                      title: Text('درس $l — Lektion $l',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${count(l)} واژه'),
                      trailing: CircleAvatar(child: Text('$l')),
                      onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                              builder: (_) => LearnSession(
                                  words:
                                      w.where((x) => x.lessons.contains(l)).toList(),
                                  title: 'درس $l'))))))
      ]));
}
