import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:flashcards/data/database/app_database.dart';
import 'package:flashcards/data/repositories/cards_repository.dart';
import 'package:flashcards/data/repositories/decks_repository.dart';
import 'package:flashcards/data/repositories/stats_repository.dart';

void main() {
  setUpAll(() {
    // On Linux CI/desktop the unversioned .so symlink may be absent.
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  late AppDatabase db;
  late DecksRepository decks;
  late CardsRepository cards;
  late StatsRepository stats;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    decks = DecksRepository(db);
    cards = CardsRepository(db);
    stats = StatsRepository(db);
  });

  tearDown(() => db.close());

  test('create deck → add card → query due cards', () async {
    final now = DateTime.now();

    final deckId = await decks.createDeck(DecksCompanion.insert(
      name: 'Test Deck',
      sourceLanguage: 'pl',
      targetLanguage: 'en',
      createdAt: now,
      updatedAt: now,
    ));

    await cards.createCard(CardsCompanion.insert(
      deckId: deckId,
      sourceText: 'kot',
      targetText: 'cat',
      createdAt: now,
      nextReview: now,
    ));

    final due = await cards.getDueCards(deckId, now);
    expect(due.length, 1);
    expect(due.first.sourceText, 'kot');
    expect(due.first.targetText, 'cat');
  });

  test('cascade delete: deleting deck removes its cards', () async {
    final now = DateTime.now();

    final deckId = await decks.createDeck(DecksCompanion.insert(
      name: 'Cascade Test',
      sourceLanguage: 'en',
      targetLanguage: 'de',
      createdAt: now,
      updatedAt: now,
    ));

    await cards.createCard(CardsCompanion.insert(
      deckId: deckId,
      sourceText: 'dog',
      targetText: 'Hund',
      createdAt: now,
      nextReview: now,
    ));

    await decks.deleteDeck(deckId);

    final remaining = await cards.getDueCards(deckId, now);
    expect(remaining, isEmpty);
  });

  test('streak: first session sets streak to 1', () async {
    final today = DateTime(2026, 5, 21);
    await stats.updateStreak(today);

    final s = await stats.getStats();
    expect(s!.currentStreak, 1);
    expect(s.longestStreak, 1);
  });

  test('streak: consecutive days extend streak', () async {
    await stats.updateStreak(DateTime(2026, 5, 20));
    await stats.updateStreak(DateTime(2026, 5, 21));

    final s = await stats.getStats();
    expect(s!.currentStreak, 2);
    expect(s.longestStreak, 2);
  });

  test('streak: same day does not double-count', () async {
    final today = DateTime(2026, 5, 21, 9, 0);
    final todayLater = DateTime(2026, 5, 21, 20, 0);
    await stats.updateStreak(today);
    await stats.updateStreak(todayLater);

    final s = await stats.getStats();
    expect(s!.currentStreak, 1);
  });

  test('streak: gap resets streak', () async {
    await stats.updateStreak(DateTime(2026, 5, 19));
    await stats.updateStreak(DateTime(2026, 5, 21)); // skipped the 20th

    final s = await stats.getStats();
    expect(s!.currentStreak, 1);
  });
}
