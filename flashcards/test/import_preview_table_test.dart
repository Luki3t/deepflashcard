import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flashcards/features/settings/import_preview_table.dart';
import 'package:flashcards/features/settings/import_service.dart';

void main() {
  const rows = [
    ParsedCsvCard(sourceText: 'dog', targetText: 'pies'),
    ParsedCsvCard(sourceText: 'cat', targetText: 'kot', notes: 'animal'),
  ];

  Future<void> pumpTable(
    WidgetTester tester, {
    required List<ParsedCsvCard> rows,
    (String, String)? languages,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportPreviewTable(rows: rows, languages: languages),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('labels each column with the language it will be stored as', (
    tester,
  ) async {
    await pumpTable(tester, rows: rows, languages: ('en', 'pl'));

    expect(find.text('SOURCE · 🇬🇧 English'), findsOneWidget);
    expect(find.text('TARGET · 🇵🇱 Polish'), findsOneWidget);
    expect(find.text('dog'), findsOneWidget);
    expect(find.text('pies'), findsOneWidget);
  });

  testWidgets('falls back to bare column names while no deck is chosen', (
    tester,
  ) async {
    await pumpTable(tester, rows: rows, languages: null);

    expect(find.text('SOURCE'), findsOneWidget);
    expect(find.text('TARGET'), findsOneWidget);
  });

  testWidgets('swapped rows put the other column under each label', (
    tester,
  ) async {
    await pumpTable(
      tester,
      rows: rows.map((r) => r.swapped).toList(),
      languages: ('en', 'pl'),
    );

    // The first column now holds the Polish text and the second the English
    // one: their left-to-right order is reversed.
    final polishX = tester.getTopLeft(find.text('pies')).dx;
    final englishX = tester.getTopLeft(find.text('dog')).dx;
    expect(polishX, lessThan(englishX));
  });

  testWidgets('marks the rows that carry notes', (tester) async {
    await pumpTable(tester, rows: rows, languages: ('en', 'pl'));

    expect(find.byIcon(Icons.note_outlined), findsOneWidget);
  });
}
