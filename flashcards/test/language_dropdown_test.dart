import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flashcards/core/widgets/language_dropdown.dart';

void main() {
  // 'pl' is the selected value and 'de' the language held by the other side of
  // the pair; both sit near the top of the list, so the opened menu (which only
  // builds the items it can show) always contains them.
  Future<void> pumpOpenDropdown(
    WidgetTester tester, {
    required void Function(String) onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LanguageDropdown(
            label: 'Learning',
            value: 'pl',
            disabledCode: 'de',
            onChanged: onChanged,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LanguageDropdown));
    await tester.pumpAndSettle();
  }

  testWidgets('the language held by the other side is disabled, the rest are '
      'selectable', (tester) async {
    await pumpOpenDropdown(tester, onChanged: (_) {});

    final items = tester
        .widgetList<DropdownMenuItem<String>>(
          find.byType(DropdownMenuItem<String>),
        )
        .toList();
    expect(items.firstWhere((i) => i.value == 'de').enabled, isFalse);
    expect(items.firstWhere((i) => i.value == 'pl').enabled, isTrue);
    expect(items.firstWhere((i) => i.value == 'es').enabled, isTrue);
  });

  testWidgets('the disabled language is greyed out', (tester) async {
    await pumpOpenDropdown(tester, onChanged: (_) {});

    final context = tester.element(find.byType(LanguageDropdown));
    final german = tester.widget<Text>(find.text('🇩🇪 German'));
    expect(german.style?.color, Theme.of(context).disabledColor);
  });

  testWidgets('tapping the disabled language does not report a change', (
    tester,
  ) async {
    final changes = <String>[];
    await pumpOpenDropdown(tester, onChanged: changes.add);

    await tester.tap(find.text('🇩🇪 German'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('tapping an enabled language reports the change', (tester) async {
    final changes = <String>[];
    await pumpOpenDropdown(tester, onChanged: changes.add);

    await tester.tap(find.text('🇪🇸 Spanish'));
    await tester.pumpAndSettle();

    expect(changes, ['es']);
  });
}
