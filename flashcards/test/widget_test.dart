import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

import 'package:flashcards/core/providers/shared_preferences_provider.dart';
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

  testWidgets('App shows onboarding on first launch', (tester) async {
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

    // Should show welcome screen
    expect(find.text('Deep Flashcard'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);

    await db.close();
  });

  testWidgets('App shows decks screen after onboarding completed',
      (tester) async {
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

    expect(find.text('My Decks'), findsOneWidget);

    await db.close();
  });
}
