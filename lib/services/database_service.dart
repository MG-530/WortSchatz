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

  /// Single source of truth: merged vocabulary (A1 + A2).
  /// Fresh installs get all words with box=0 (Leitner starts empty).
  /// Stale DBs (e.g. old 1711-word build) are reseeded while keeping
  /// the user's Leitner progress (matched by german word).
  Future<void> init() async {
    final dbPath = pth.join(await getDatabasesPath(), 'starten_wir_a1.db');
    _db = await openDatabase(dbPath, version: 2, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY, german TEXT, display TEXT, article TEXT, persian TEXT, english TEXT, pronunciation TEXT, word_type TEXT, gender TEXT, level TEXT, lessons TEXT, box INTEGER DEFAULT 0, next_review TEXT)');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE words ADD COLUMN level TEXT');
      }
    });
    final raw =
        jsonDecode(await rootBundle.loadString('assets/vocab_merged.json'))
            as List;
    final count = Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM words')) ??
        0;
    if (count != raw.length) {
      final progress = <String, Map<String, Object?>>{};
      try {
        final rows = await _db!
            .query('words', columns: ['german', 'box', 'next_review']);
        for (final r in rows) {
          final g = r['german'] as String?;
          if (g != null && g.isNotEmpty) {
            progress[g] = {
              'box': r['box'] ?? 0,
              'next_review': r['next_review']
            };
          }
        }
      } catch (_) {}
      await _db!.delete('words');
      final batch = _db!.batch();
      for (var i = 0; i < raw.length; i++) {
        final x = Map<String, dynamic>.from(raw[i]);
        final g = x['german'] ?? '';
        final p = progress[g];
        batch.insert('words', {
          'id': i + 1,
          'german': g,
          'display': x['display'] ?? '',
          'article': x['article'] ?? '',
          'persian': x['persian'] ?? '',
          'english': x['english'] ?? '',
          'pronunciation': x['pronunciation'] ?? '',
          'word_type': x['word_type'] ?? 'other',
          'gender': x['gender'] ?? '',
          'level': x['level'] ?? 'A1',
          'lessons': (x['lessons'] as List? ?? []).join(','),
          'box': p?['box'] ?? 0,
          'next_review': p?['next_review']
        });
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> init_merged() => init();

  Future<List<Word>> all({String query = '', String? level, int? lesson, String? wordType}) async {
    var where = <String>[];
    var args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(german LIKE ? OR persian LIKE ? OR english LIKE ?)');
      args += ['%$query%', '%$query%', '%$query%'];
    }
    if (level != null) {
      where.add('level LIKE ?');
      args.add('%$level%');
    }
    if (lesson != null) {
      where.add('lessons LIKE ?');
      args.add('%$lesson%');
    }
    if (wordType != null) {
      where.add('word_type = ?');
      args.add(wordType);
    }
    final rows = await _db!.query('words',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'id');
    return rows.map(Word.fromMap).toList();
  }

  Future<List<Word>> due({String? level}) async {
    final now = DateTime.now().toIso8601String();
    final where = level == null
        ? 'box > 0 AND (next_review IS NULL OR next_review <= ?)'
        : 'box > 0 AND level LIKE ? AND (next_review IS NULL OR next_review <= ?)';
    final args =
        level == null ? [now] : ['%$level%', now];
    final rows = await _db!.rawQuery(
        'SELECT * FROM words WHERE $where ORDER BY next_review LIMIT 30',
        args);
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

  Batch batch() => _db!.batch();

  Future<Map<String, int>> stats({String? level}) async {
    final where = level == null ? '' : 'WHERE level LIKE ?';
    final args = level == null ? <Object?>[] : ['%$level%'];
    final r = await _db!.rawQuery(
        'SELECT COUNT(*) total, SUM(CASE WHEN box > 0 THEN 1 ELSE 0 END) learned, SUM(CASE WHEN box = 0 THEN 1 ELSE 0 END) fresh FROM words $where',
        args);
    final x = r.first;
    return {
      'total': (x['total'] as int?) ?? 0,
      'learned': (x['learned'] as int?) ?? 0,
      'fresh': (x['fresh'] as int?) ?? 0,
      'due': (await due(level: level)).length
    };
  }
}