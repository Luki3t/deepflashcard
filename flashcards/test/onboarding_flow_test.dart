import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

import 'package:flashcards/core/providers/shared_preferences_provider.dart';
import 'package:flashcards/data/database/app_database.dart';
import 'package:flashcards/data/database/database_provider.dart';
import 'package:flashcards/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  Future<(SharedPreferences, AppDatabase)> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
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
    return (prefs, db);
  }

  testWidgets(
    'completing the onboarding flow persists the chosen languages and creates the first deck',
    (tester) async {
      final (prefs, db) = await pumpApp(tester);

      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('What is your native language?'), findsOneWidget);
      await tester.tap(find.text('German'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('What do you want to learn?'), findsOneWidget);
      await tester.tap(find.text('Polish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Ready to learn!'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
      expect(find.text('Polish'), findsOneWidget);

      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();

      expect(find.text('My Decks'), findsOneWidget);
      expect(prefs.getString('native_language_code'), 'de');
      expect(prefs.getString('target_language_code'), 'pl');
      expect(prefs.getBool('onboarding_completed'), isTrue);

      final decks = await db.select(db.decks).get();
      expect(decks, hasLength(1));
      expect(decks.single.sourceLanguage, 'de');
      expect(decks.single.targetLanguage, 'pl');

      await db.close();
    },
  );

  testWidgets(
    'the just-picked native language cannot also be picked as the target',
    (tester) async {
      final (_, db) = await pumpApp(tester);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      // Keep the default native language (English) and move on.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('What do you want to learn?'), findsOneWidget);

      final englishTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('English'),
          matching: find.byType(ListTile),
        ),
      );
      expect(englishTile.enabled, isFalse);

      // Tapping the disabled tile must not change the selection away from
      // the default target (Polish).
      await tester.tap(find.text('English'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Polish'), findsOneWidget);

      await db.close();
    },
  );

  testWidgets(
    'picking the default target language as the native one moves the target '
    'off it instead of creating a same-language deck',
    (tester) async {
      final (prefs, db) = await pumpApp(tester);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // The target defaults to Polish; pick Polish as the native language too.
      expect(find.text('What is your native language?'), findsOneWidget);
      await tester.tap(find.text('Polish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // The target screen has moved off Polish, which is now disabled there.
      expect(find.text('What do you want to learn?'), findsOneWidget);
      final polishTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Polish'), matching: find.byType(ListTile)),
      );
      expect(polishTile.enabled, isFalse);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();

      expect(prefs.getString('native_language_code'), 'pl');
      expect(prefs.getString('target_language_code'), isNot('pl'));

      final deck = await db.select(db.decks).getSingle();
      expect(deck.sourceLanguage, 'pl');
      expect(deck.targetLanguage, isNot('pl'));

      await db.close();
    },
  );
}
