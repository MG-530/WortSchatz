import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  /// Enrollment model:
  /// - box < 0  (-1): NOT in Leitner yet (fresh pool, invisible to review).
  /// - box == 0: Leitner entry — enrolled via explicit "add to Leitner".
  /// - box 1..5: Leitner progress.
  /// Fresh installs seed everything as -1, so every box (including box 0)
  /// starts empty. Entry into Leitner is ONLY box -1 → 0 through add
  /// actions; re-adding enrolled words is impossible by construction.
  Future<void> init() async {
    final dbPath = pth.join(await getDatabasesPath(), 'starten_wir_a1.db');
    _db = await openDatabase(dbPath, version: 3, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY, german TEXT, display TEXT, article TEXT, persian TEXT, english TEXT, pronunciation TEXT, word_type TEXT, gender TEXT, level TEXT, lessons TEXT, box INTEGER DEFAULT 0, next_review TEXT)');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE words ADD COLUMN level TEXT');
      }
      if (oldVersion < 3) {
        // One-way migration to the enrollment model: old box-0 rows were
        // never deliberately enrolled (old add went straight to box 1),
        // so they become unenrolled (-1). Rows in boxes >= 1 keep the
        // user's real progress and are never touched.
        await db.rawUpdate(
            'UPDATE words SET box = -1, next_review = NULL WHERE box = 0');
      }
    });
    final raw =
        jsonDecode(await rootBundle.loadString('assets/vocab_merged.json'))
            as List;
    final count = Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM words')) ??
        0;
    final fresh = count != raw.length;
    if (fresh) {
      await _db!.execute('DROP TABLE IF EXISTS words');
      await _db!.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY, german TEXT, display TEXT, article TEXT, persian TEXT, english TEXT, pronunciation TEXT, word_type TEXT, gender TEXT, level TEXT, lessons TEXT, box INTEGER DEFAULT 0, next_review TEXT)');
    }
    final words = <Map<String, dynamic>>[];
    for (final x in raw) {
      // Lesson numbers are ALWAYS 1..12. The old 101..112 A2 offset was
      // only a level hack — the level column distinguishes levels now.
      final lessons = (x['lessons'] as List? ?? []).map((l) {
        final n = l as int;
        return n > 100 ? n - 100 : n;
      }).join(',');
      words.add({
        'id': words.length + 1,
        'german': x['german'] ?? '',
        'display': x['display'] ?? '',
        'article': x['article'] ?? '',
        'persian': x['persian'] ?? '',
        'english': x['english'] ?? '',
        'pronunciation': x['pronunciation'] ?? '',
        'word_type': x['word_type'] ?? 'other',
        'gender': x['gender'] ?? '',
        'level': x['level'] ?? 'A1',
        'lessons': lessons,
        'box': -1,
        'next_review': null,
      });
    }
    try {
      if (fresh) {
        for (var chunkStart = 0; chunkStart < words.length; chunkStart += 500) {
          final chunkEnd = (chunkStart + 500 < words.length)
              ? chunkStart + 500
              : words.length;
          for (var i = chunkStart; i < chunkEnd; i++) {
            await _db!.insert('words', words[i]);
          }
        }
      } else {
        // Same word count: only backfill metadata (level, normalized
        // lessons, and b-amooz-checked word_type/article/gender/display).
        // NEVER touch box / next_review here — resetting them would wipe
        // the user's Leitner progress on every app start.
        // This also migrates old DBs storing A2 lessons as 101..112.
        for (var i = 0; i < words.length; i++) {
          await _db!.update(
              'words',
              {
                'level': words[i]['level'],
                'lessons': words[i]['lessons'],
                'word_type': words[i]['word_type'],
                'article': words[i]['article'],
                'gender': words[i]['gender'],
                'display': words[i]['display'],
              },
              where: 'id = ?',
              whereArgs: [words[i]['id']]);
        }
      }
    } catch (e, st) {
      // Never fail silently: log the seed error, then attempt a
      // non-destructive fallback (metadata backfill only, progress kept).
      // If even the fallback fails, rethrow so the failure surfaces
      // instead of corrupting data quietly.
      debugPrint('VocabularyDb seed failed: $e\n$st');
      try {
        for (var i = 0; i < words.length; i++) {
          await _db!.update(
              'words',
              {
                'level': words[i]['level'],
                'lessons': words[i]['lessons'],
                'word_type': words[i]['word_type'],
                'article': words[i]['article'],
                'gender': words[i]['gender'],
                'display': words[i]['display'],
              },
              where: 'id = ?',
              whereArgs: [words[i]['id']]);
        }
      } catch (e2, st2) {
        debugPrint('VocabularyDb fallback seed failed: $e2\n$st2');
        rethrow;
      }
    }
    await _ensureConjugations();
  }

  /// Verb conjugation tables (seeded from assets, no user data inside so a
  /// reseed-if-empty is always safe). Works on pre-existing databases too
  /// — no schema version bump needed for the words table.
  Future<void> _ensureConjugations() async {
    await _db!.execute(
        'CREATE TABLE IF NOT EXISTS conjugations(verb TEXT PRIMARY KEY, url TEXT, data TEXT)');
    await _db!.execute(
        'CREATE TABLE IF NOT EXISTS conj_aliases(word TEXT PRIMARY KEY, verb TEXT)');
    final count = Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM conjugations')) ??
        0;
    if (count > 0) return;
    final cmap =
        jsonDecode(await rootBundle.loadString('assets/conjugations.json'))
            as Map<String, dynamic>;
    final batch = _db!.batch();
    cmap.forEach((verb, v) {
      if (verb == '_aliases') return;
      final m = v as Map<String, dynamic>;
      batch.insert('conjugations', {
        'verb': verb,
        'url': m['url'] ?? '',
        'data': jsonEncode(m['moods'] ?? []),
      });
    });
    final aliases = cmap['_aliases'] as Map<String, dynamic>? ?? {};
    aliases.forEach((word, verb) {
      batch.insert('conj_aliases', {'word': word, 'verb': verb as String});
    });
    await batch.commit(noResult: true);
  }

  /// Conjugation tables for a German word, or null when the word has none.
  /// Resolution: exact verb → alias (e.g. ist → sein) → lowercase fallback.
  /// Returns {'verb', 'url', 'moods'} where moods is a decoded List.
  Future<Map<String, dynamic>?> conjugationFor(String german) async {
    Future<Map<String, Object?>?> one(String sql, List<Object?> args) async {
      final r = await _db!.rawQuery(sql, args);
      return r.isEmpty ? null : r.first;
    }

    var row = await one('SELECT * FROM conjugations WHERE verb = ?', [german]);
    if (row == null) {
      final a =
          await one('SELECT verb FROM conj_aliases WHERE word = ?', [german]);
      if (a != null) {
        row =
            await one('SELECT * FROM conjugations WHERE verb = ?', [a['verb']]);
      }
    }
    if (row == null && german != german.toLowerCase()) {
      row = await one(
          'SELECT * FROM conjugations WHERE verb = ?', [german.toLowerCase()]);
    }
    if (row == null) return null;
    return {
      'verb': row['verb'] as String? ?? german,
      'url': row['url'] as String? ?? '',
      'moods': jsonDecode(row['data'] as String? ?? '[]'),
    };
  }

  Future<void> init_merged() => init();

  Future<List<Word>> all(
      {String query = '', String? level, int? lesson, String? wordType}) async {
    var where = <String>[];
    var args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(german LIKE ? OR persian LIKE ? OR english LIKE ?)');
      args += ['%$query%', '%$query%', '%$query%'];
    }
    if (level != null) {
      where.add('level = ?');
      args.add(level);
    }
    if (lesson != null) {
      // Exact lesson match: comma-wrap so lesson 1 doesn't match 10..12.
      where.add("(',' || lessons || ',') LIKE ?");
      args.add('%,$lesson,%');
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
    final args = level == null ? [now] : ['%$level%', now];
    final rows = await _db!.rawQuery(
        'SELECT * FROM words WHERE $where ORDER BY next_review LIMIT 30', args);
    return rows.map(Word.fromMap).toList();
  }

  Future<bool> isDue(Word w) async {
    if (w.box == 0 || w.nextReview == null) return true;
    return !w.nextReview!.isAfter(DateTime.now());
  }

  /// Grade a Leitner answer. Unenrolled words (box < 0) are NEVER
  /// auto-enrolled by studying or reviewing — enrollment happens only
  /// through explicit "add to Leitner" actions (box -1 → 0). Enrolled
  /// words (box >= 0) grade normally: box 0 → 1 → … → 5 on known,
  /// one box back on forgotten. Re-adding is impossible because add
  /// paths only accept box < 0.
  Future<void> grade(Word w, bool known) async {
    if (w.box < 0) return;
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
    final where = level == null ? '' : 'WHERE level = ?';
    final args = level == null ? <Object?>[] : [level];
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
