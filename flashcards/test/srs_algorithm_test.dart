import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:drift/drift.dart' show Value;
import 'package:flashcards/data/database/app_database.dart';
import 'package:flashcards/features/study/srs_algorithm.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<FlashCard> makeCard({
    double easeFactor = 2.5,
    int intervalDays = 0,
    int repetitions = 0,
  }) async {
    final now = DateTime.now();
    final deckId = await db.into(db.decks).insert(DecksCompanion.insert(
          name: 'Test',
          sourceLanguage: 'en',
          targetLanguage: 'pl',
          createdAt: now,
          updatedAt: now,
        ));
    final cardId = await db.into(db.cards).insert(CardsCompanion.insert(
          deckId: deckId,
          sourceText: 'hello',
          targetText: 'cześć',
          createdAt: now,
          nextReview: now,
          easeFactor: Value(easeFactor),
          intervalDays: Value(intervalDays),
          repetitions: Value(repetitions),
        ));
    return (db.select(db.cards)
          ..where((c) => c.id.equals(cardId)))
        .getSingle();
  }

  final now = DateTime(2026, 5, 27, 12);

  group('Again (rating=0)', () {
    test('resets repetitions to 0 and interval to 1', () async {
      final card = await makeCard(repetitions: 3, intervalDays: 10);
      final r = applySM2(card, 0, now);
      expect(r.repetitions, 0);
      expect(r.intervalDays, 1);
    });

    test('EF decreases but stays above 1.3', () async {
      final card = await makeCard(easeFactor: 1.4);
      final r = applySM2(card, 0, now);
      expect(r.easeFactor, greaterThanOrEqualTo(1.3));
    });
  });

  group('First review (repetitions=0)', () {
    test('Good → interval=1, reps=1', () async {
      final card = await makeCard();
      final r = applySM2(card, 4, now);
      expect(r.intervalDays, 1);
      expect(r.repetitions, 1);
    });

    test('Easy → interval=1, reps=1', () async {
      final card = await makeCard();
      final r = applySM2(card, 5, now);
      expect(r.intervalDays, 1);
      expect(r.repetitions, 1);
    });
  });

  group('Second review (repetitions=1)', () {
    test('Good → interval=6, reps=2', () async {
      final card = await makeCard(repetitions: 1, intervalDays: 1);
      final r = applySM2(card, 4, now);
      expect(r.intervalDays, 6);
      expect(r.repetitions, 2);
    });
  });

  group('Subsequent reviews (repetitions>=2)', () {
    test('interval = round(prev * EF)', () async {
      final card = await makeCard(
          repetitions: 2, intervalDays: 6, easeFactor: 2.5);
      final r = applySM2(card, 4, now);
      expect(r.intervalDays, (6 * 2.5).round()); // 15
    });
  });

  group('EF updates', () {
    test('EF increases for Easy (5)', () async {
      final card = await makeCard(easeFactor: 2.5);
      final r = applySM2(card, 5, now);
      expect(r.easeFactor, greaterThan(2.5));
    });

    test('EF stays same for Good (4)', () async {
      final card = await makeCard(easeFactor: 2.5);
      final r = applySM2(card, 4, now);
      expect(r.easeFactor, closeTo(2.5, 0.01));
    });

    test('EF decreases for Hard (3)', () async {
      final card = await makeCard(easeFactor: 2.5);
      final r = applySM2(card, 3, now);
      expect(r.easeFactor, lessThan(2.5));
    });

    test('EF floor is 1.3', () async {
      final card = await makeCard(easeFactor: 1.3);
      final r = applySM2(card, 0, now);
      expect(r.easeFactor, 1.3);
    });
  });

  group('nextReview', () {
    test('next review is intervalDays from now', () async {
      final card = await makeCard(repetitions: 1, intervalDays: 1);
      final r = applySM2(card, 4, now);
      final expected = now.add(Duration(days: r.intervalDays));
      expect(r.nextReview.difference(expected).inSeconds.abs(), lessThan(1));
    });
  });

  group('formatInterval', () {
    test('1 day', () => expect(formatInterval(1), '1d'));
    test('6 days', () => expect(formatInterval(6), '6d'));
    test('30 days → months', () => expect(formatInterval(30), '1mo'));
    test('365 days → years', () => expect(formatInterval(365), '1y'));
  });
}
