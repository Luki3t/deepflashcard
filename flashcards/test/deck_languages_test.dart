import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

import 'package:flashcards/core/constants/languages.dart';
import 'package:flashcards/core/providers/shared_preferences_provider.dart';
import 'package:flashcards/core/widgets/language_dropdown.dart';
import 'package:flashcards/data/database/app_database.dart';
import 'package:flashcards/data/database/database_provider.dart';
import 'package:flashcards/main.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  Future<AppDatabase> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'native_language_code': 'en',
      'target_language_code': 'pl',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const FlashcardsApp(),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  LanguageDropdown dropdownAt(WidgetTester tester, int index) =>
      tester.widget<LanguageDropdown>(find.byType(LanguageDropdown).at(index));

  group('new deck sheet', () {
    testWidgets('each dropdown blocks the language held by the other side', (
      tester,
    ) async {
      final db = await pumpApp(tester);

      await tester.tap(find.text('New Deck'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageDropdown), findsNWidgets(2));

      // Native is 'en', learning is 'pl' (from the stored preferences), and
      // each side is blocked from picking the other's language.
      final native = dropdownAt(tester, 0);
      final learning = dropdownAt(tester, 1);
      expect(native.value, 'en');
      expect(native.disabledCode, 'pl');
      expect(learning.value, 'pl');
      expect(learning.disabledCode, 'en');

      await db.close();
    });

    testWidgets('falls back to a different target when the stored preferences '
        'hold the same language twice', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'native_language_code': 'pl',
        'target_language_code': 'pl',
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const FlashcardsApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Deck'));
      await tester.pumpAndSettle();

      final native = dropdownAt(tester, 0);
      final learning = dropdownAt(tester, 1);
      expect(native.value, 'pl');
      expect(learning.value, isNot('pl'));
      expect(learning.value, firstLanguageOtherThan('pl'));

      await db.close();
    });
  });

  group('edit deck sheet', () {
    testWidgets('offers no language pickers, only the deck languages as text', (
      tester,
    ) async {
      final db = await pumpApp(tester);
      final now = DateTime.now();
      await db
          .into(db.decks)
          .insert(
            DecksCompanion.insert(
              name: 'Reise',
              sourceLanguage: 'de',
              targetLanguage: 'es',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reise'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit deck'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Deck'), findsOneWidget);
      expect(find.byType(LanguageDropdown), findsNothing);
      expect(
        find.text(
          'Languages are set when the deck is created and cannot be changed.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('German'), findsOneWidget);
      expect(find.textContaining('Spanish'), findsOneWidget);

      // Tear the tree down so the screen's watchers unsubscribe, then let the
      // pending drift timers run so closing the database can complete.
      await tester.pumpWidget(const SizedBox.shrink());
      final closing = db.close();
      await tester.pump(const Duration(milliseconds: 100));
      await closing;
    });
  });
}
