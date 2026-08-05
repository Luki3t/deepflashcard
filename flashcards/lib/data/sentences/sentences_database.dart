import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class ExampleSentence {
  const ExampleSentence({required this.source, required this.target});
  final String source;
  final String target;
}

class SentencesDatabase {
  static const _subdir = 'sentences';

  Future<String> _dbPath(String source, String target) async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, _subdir, 'tatoeba_$source-$target.db');
  }

  Future<bool> isPairDownloaded(String source, String target) async {
    final path = await _dbPath(source, target);
    return File(path).existsSync();
  }

  Future<List<ExampleSentence>> findExamples(
    String word,
    String source,
    String target, {
    int limit = 5,
  }) async {
    final path = await _dbPath(source, target);
    if (!File(path).existsSync()) return [];
    try {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        final escaped = '"${word.replaceAll('"', '""')}"';
        final rows = db.select(
          'SELECT s.source_text, s.target_text '
          'FROM sentences s '
          'JOIN sentences_fts fts ON fts.rowid = s.id '
          'WHERE sentences_fts MATCH ? '
          'ORDER BY s.source_length ASC '
          'LIMIT ?',
          [escaped, limit],
        );
        return rows
            .map(
              (r) => ExampleSentence(
                source: r['source_text'] as String,
                target: r['target_text'] as String,
              ),
            )
            .toList();
      } finally {
        db.dispose();
      }
    } catch (_) {
      return [];
    }
  }

  Future<void> deletePair(String source, String target) async {
    final path = await _dbPath(source, target);
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  Future<List<String>> downloadedPairs() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subdir));
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .map(
          (f) =>
              p.basenameWithoutExtension(f.path).replaceFirst('tatoeba_', ''),
        )
        .toList()
      ..sort();
  }
}

final sentencesDatabaseProvider = Provider<SentencesDatabase>(
  (ref) => SentencesDatabase(),
);
