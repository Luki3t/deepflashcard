import 'package:flutter_test/flutter_test.dart';

import 'package:flashcards/features/settings/import_service.dart';

void main() {
  const service = ImportService();

  group('empty input', () {
    test('empty string produces a single "file is empty" error', () {
      final result = service.parse('');
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, 'The file is empty.');
    });

    test('whitespace-only content produces a single "file is empty" error',
        () {
      final result = service.parse('   \n  \n');
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, 'The file is empty.');
    });

    test('header row only produces no rows and no errors', () {
      final result = service.parse('source_text,target_text,notes');
      expect(result.rows, isEmpty);
      expect(result.errors, isEmpty);
    });
  });

  group('valid rows', () {
    test('parses a 2-column row (no notes)', () {
      final result = service.parse(
        'source_text,target_text\nkot,cat',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.sourceText, 'kot');
      expect(result.rows.first.targetText, 'cat');
      expect(result.rows.first.notes, isNull);
    });

    test('parses a 3-column row with notes', () {
      final result = service.parse(
        'source_text,target_text,notes\nkot,cat,domestic animal',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.notes, 'domestic animal');
    });

    test('empty notes column is treated as null, not empty string', () {
      final result = service.parse(
        'source_text,target_text,notes\nkot,cat,',
      );
      expect(result.errors, isEmpty);
      expect(result.rows.first.notes, isNull);
    });

    test('trims whitespace around field values', () {
      final result = service.parse(
        'source_text,target_text\n  kot  ,  cat  ',
      );
      expect(result.rows.first.sourceText, 'kot');
      expect(result.rows.first.targetText, 'cat');
    });

    test('parses multiple valid rows in order', () {
      final result = service.parse(
        'source_text,target_text\nkot,cat\npies,dog\nptak,bird',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(3));
      expect(result.rows.map((r) => r.sourceText), ['kot', 'pies', 'ptak']);
    });

    test('quoted field containing the delimiter is parsed as one value', () {
      final result = service.parse(
        'source_text,target_text,notes\nkot,cat,"informal, everyday word"',
      );
      expect(result.errors, isEmpty);
      expect(result.rows.first.notes, 'informal, everyday word');
    });

    test('strips a leading UTF-8 BOM before parsing', () {
      final result = service.parse(
        '﻿source_text,target_text\nkot,cat',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.sourceText, 'kot');
    });

    test('supports a custom field delimiter', () {
      final result = service.parse(
        'source_text;target_text;notes\nkot;cat;animal',
        fieldDelimiter: ';',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.first.sourceText, 'kot');
      expect(result.rows.first.notes, 'animal');
    });
  });

  group('row-level errors', () {
    test('blank line is silently skipped (no row, no error)', () {
      final result = service.parse(
        'source_text,target_text\nkot,cat\n\npies,dog',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(2));
    });

    test('row with only 1 column is an error with the correct line number',
        () {
      final result = service.parse(
        'source_text,target_text\nkot,cat\njust_one_field',
      );
      expect(result.rows, hasLength(1));
      expect(result.errors, hasLength(1));
      expect(result.errors.first.line, 3);
      expect(result.errors.first.message, contains('Expected 2-3 columns'));
      expect(result.errors.first.message, contains('found 1'));
    });

    test('row with more than 3 columns is an error', () {
      final result = service.parse(
        'source_text,target_text\nkot,cat,note,extra,too_many',
      );
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, contains('found 5'));
    });

    test('empty source_text is an error', () {
      final result = service.parse(
        'source_text,target_text\n,cat',
      );
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(
        result.errors.first.message,
        'source_text and target_text cannot be empty.',
      );
    });

    test('empty target_text is an error', () {
      final result = service.parse(
        'source_text,target_text\nkot,',
      );
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(
        result.errors.first.message,
        'source_text and target_text cannot be empty.',
      );
    });

    test('error line numbers count the header as line 1', () {
      final result = service.parse(
        'source_text,target_text\nkot,cat\npies,dog\n,broken',
      );
      expect(result.errors, hasLength(1));
      // header=1, kot/cat=2, pies/dog=3, broken row=4
      expect(result.errors.first.line, 4);
    });

    test('valid and invalid rows can be interleaved; valid ones still '
        'parse', () {
      final result = service.parse(
        'source_text,target_text\n'
        'kot,cat\n'
        ',missing_source\n'
        'pies,dog\n'
        'too,many,columns,here',
      );
      expect(result.rows, hasLength(2));
      expect(result.rows.map((r) => r.sourceText), ['kot', 'pies']);
      expect(result.errors, hasLength(2));
      expect(result.errors[0].line, 3);
      expect(result.errors[1].line, 5);
    });
  });

  group('swapped columns', () {
    test('exchanges the two texts and keeps the notes', () {
      const card = ParsedCsvCard(
        sourceText: 'kot',
        targetText: 'cat',
        notes: 'animal',
      );
      expect(card.swapped.sourceText, 'cat');
      expect(card.swapped.targetText, 'kot');
      expect(card.swapped.notes, 'animal');
    });

    test('swapping twice returns the original mapping', () {
      const card = ParsedCsvCard(sourceText: 'kot', targetText: 'cat');
      expect(card.swapped.swapped.sourceText, 'kot');
      expect(card.swapped.swapped.targetText, 'cat');
    });
  });
}
