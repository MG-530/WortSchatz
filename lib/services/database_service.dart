import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as pth;
import '../models/word.dart';

class VocabularyDb {
  VocabularyDb._();
  static final instance = VocabularyDb._();
  Database? _db;

  Future<void> init() async {
    final dbPath = pth.join(await getDatabasesPath(), 'starten_wir_a1.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY, german TEXT, display TEXT, article TEXT, persian TEXT, english TEXT, pronunciation TEXT, word_type TEXT, gender TEXT, lessons TEXT, box INTEGER DEFAULT 0, next_review TEXT)');
    });
    final count = Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM words')) ??
        0;
    if (count == 0) {
      final raw = jsonDecode(await rootBundle.loadString('assets/vocab.json')) as List;
      final batch = _db!.batch();
      for (var i = 0; i < raw.length; i++) {
        final x = Map<String, dynamic>.from(raw[i]);
        batch.insert('words', {
          'id': i + 1,
          'german': x['german'] ?? '',
          'display': x['display'] ?? '',
          'article': x['article'] ?? '',
          'persian': x['persian'] ?? '',
          'english': x['english'] ?? '',
          'pronunciation': x['pronunciation'] ?? '',
          'word_type': x['word_type'] ?? 'other',
          'gender': x['gender'] ?? '',
          'lessons': (x['lessons'] as List? ?? []).join(','),
          'box': 0
        });
      }
      await batch.commit(noResult: true);
    }
  }

  Future<List<Word>> all({String query = '', int? lesson}) async {
    var where = <String>[];
    var args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(german LIKE ? OR persian LIKE ? OR english LIKE ?)');
      args += ['%$query%', '%$query%', '%$query%'];
    }
    if (lesson != null) {
      where.add('lessons LIKE ?');
      args.add('%$lesson%');
    }
    final rows = await _db!.query('words',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'id');
    return rows.map(Word.fromMap).toList();
  }

  Future<List<Word>> due() async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db!.rawQuery(
        'SELECT * FROM words WHERE box > 0 AND (next_review IS NULL OR next_review <= ?) ORDER BY next_review LIMIT 30',
        [now]);
    return rows.map(Word.fromMap).toList();
  }

  Future<bool> isDue(Word w) async {
    if (w.box == 0 || w.nextReview == null) return true;
    return !w.nextReview!.isAfter(DateTime.now());
  }

  Future<void> grade(Word w, bool known) async {
    if (!await isDue(w)) return;
    final box = known ? min(5, w.box + 1) : max(0, w.box - 1);
    final days = [0, 1, 2, 4, 7, 14][box];
    final next = box == 0
        ? null
        : DateTime.now().add(Duration(days: days)).toIso8601String();
    await _db!.update('words', {'box': box, 'next_review': next},
        where: 'id = ?', whereArgs: [w.id]);
  }

  Future<List<Map<String, dynamic>>> backupRows() async =>
      await _db!.query('words', orderBy: 'id');

  Future<void> restoreRows(List<dynamic> rows) async {
    final batch = _db!.batch();
    for (final raw in rows) {
      final x = Map<String, dynamic>.from(raw as Map);
      if (x['id'] != null)
        batch.update(
            'words', {'box': x['box'] ?? 0, 'next_review': x['next_review']},
            where: 'id = ?', whereArgs: [x['id']]);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, int>> stats() async {
    final r = await _db!.rawQuery(
        'SELECT COUNT(*) total, SUM(CASE WHEN box > 0 THEN 1 ELSE 0 END) learned, SUM(CASE WHEN box = 0 THEN 1 ELSE 0 END) fresh FROM words');
    final x = r.first;
    return {
      'total': (x['total'] as int?) ?? 0,
      'learned': (x['learned'] as int?) ?? 0,
      'fresh': (x['fresh'] as int?) ?? 0,
      'due': (await due()).length
    };
  }
}
