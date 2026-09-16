import 'package:csv/csv.dart';

class CsvRowError {
  const CsvRowError(this.line, this.message);
  final int line;
  final String message;
}

class ParsedCsvCard {
  const ParsedCsvCard({
    required this.sourceText,
    required this.targetText,
    this.notes,
  });
  final String sourceText;
  final String targetText;
  final String? notes;

  /// The same card with the two text columns exchanged, for files whose
  /// columns are in the reverse of the expected order.
  ParsedCsvCard get swapped => ParsedCsvCard(
    sourceText: targetText,
    targetText: sourceText,
    notes: notes,
  );
}

class CsvParseResult {
  const CsvParseResult({required this.rows, required this.errors});
  final List<ParsedCsvCard> rows;
  final List<CsvRowError> errors;
}

/// Parses CSV in the `source_text,target_text,notes` format (header
/// required, notes column optional). Line numbers in errors are 1-indexed
/// and refer to the position in the file, counting the header as line 1.
class ImportService {
  const ImportService();

  CsvParseResult parse(String rawContent, {String fieldDelimiter = ','}) {
    final content = rawContent.startsWith('﻿')
        ? rawContent.substring(1)
        : rawContent;

    if (content.trim().isEmpty) {
      return const CsvParseResult(
        rows: [],
        errors: [CsvRowError(0, 'The file is empty.')],
      );
    }

    final table = CsvToListConverter(
      shouldParseNumbers: false,
      fieldDelimiter: fieldDelimiter,
    ).convert(content, eol: '\n');

    if (table.isEmpty) {
      return const CsvParseResult(
        rows: [],
        errors: [CsvRowError(0, 'The file is empty.')],
      );
    }

    final rows = <ParsedCsvCard>[];
    final errors = <CsvRowError>[];

    // First row is treated as the header and skipped.
    for (var i = 1; i < table.length; i++) {
      final line = i + 1;
      final rawRow = table[i];
      final row = rawRow.map((v) => v.toString().trim()).toList();

      if (row.isEmpty || row.every((v) => v.isEmpty)) {
        continue; // blank line, ignore silently
      }

      if (row.length < 2 || row.length > 3) {
        errors.add(
          CsvRowError(
            line,
            'Expected 2-3 columns (source_text, target_text, notes), '
            'found ${row.length}.',
          ),
        );
        continue;
      }

      final sourceText = row[0];
      final targetText = row[1];
      if (sourceText.isEmpty || targetText.isEmpty) {
        errors.add(
          CsvRowError(line, 'source_text and target_text cannot be empty.'),
        );
        continue;
      }

      final notes = row.length > 2 && row[2].isNotEmpty ? row[2] : null;
      rows.add(
        ParsedCsvCard(
          sourceText: sourceText,
          targetText: targetText,
          notes: notes,
        ),
      );
    }

    return CsvParseResult(rows: rows, errors: errors);
  }
}
