import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

import 'package:flashcards/core/constants/app_constants.dart';
import 'package:flashcards/core/providers/shared_preferences_provider.dart';
import 'package:flashcards/data/database/app_database.dart';
import 'package:flashcards/data/database/database_provider.dart';
import 'package:flashcards/data/database/flash_card_status.dart';
import 'package:flashcards/data/repositories/cards_repository.dart';
import 'package:flashcards/data/repositories/decks_repository.dart';
import 'package:flashcards/data/repositories/reviews_repository.dart';
import 'package:flashcards/features/study/study_session_notifier.dart';

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
  late DecksRepository decks;
  late CardsRepository cards;
  late ReviewsRepository reviews;
  late ProviderContainer container;
  late int deckId;

  Future<void> makeContainer({Map<String, Object> prefsValues = const {}}) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<int> addNewCard(String suffix) => cards.createCard(
        CardsCompanion.insert(
          deckId: deckId,
          sourceText: 'word$suffix',
          targetText: 'slowo$suffix',
          createdAt: DateTime.now(),
          nextReview: DateTime.now(),
        ),
      );

  // Logs a review as if `count` new cards were already introduced today,
  // consuming that much of the daily new-card budget.
  Future<void> introduceNewCardsToday(int count, DateTime now) async {
    for (var i = 0; i < count; i++) {
      final cardId = await addNewCard('-introduced-$i');
      await reviews.logReview(
        ReviewLogsCompanion.insert(
          cardId: cardId,
          reviewedAt: now,
          rating: 4,
          previousInterval: 0,
          newInterval: 1,
        ),
      );
    }
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    decks = DecksRepository(db);
    cards = CardsRepository(db);
    reviews = ReviewsRepository(db);

    final now = DateTime.now();
    deckId = await decks.createDeck(
      DecksCompanion.insert(
        name: 'Study Deck',
        sourceLanguage: 'pl',
        targetLanguage: 'en',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => db.close());

  test('new cards are capped at the configured daily maximum', () async {
    for (var i = 0; i < 15; i++) {
      await addNewCard('-$i');
    }
    await makeContainer(
      prefsValues: {AppConstants.maxNewCardsPerDayKey: 10},
    );

    final state =
        await container.read(studySessionProvider(deckId).future);

    expect(state.cards.length, 10);
    expect(state.newCardLimitReached, isTrue);
  });

  test('all new cards are included when under the daily maximum', () async {
    for (var i = 0; i < 5; i++) {
      await addNewCard('-$i');
    }
    await makeContainer(
      prefsValues: {AppConstants.maxNewCardsPerDayKey: 10},
    );

    final state =
        await container.read(studySessionProvider(deckId).future);

    expect(state.cards.length, 5);
    expect(state.newCardLimitReached, isFalse);
  });

  test('new cards already introduced today count against the daily budget',
      () async {
    final now = DateTime.now();
    await introduceNewCardsToday(4, now);
    for (var i = 0; i < 10; i++) {
      await addNewCard('-fresh-$i');
    }
    await makeContainer(
      prefsValues: {AppConstants.maxNewCardsPerDayKey: 10},
    );

    final state =
        await container.read(studySessionProvider(deckId).future);

    // Budget is 10 - 4 already introduced = 6 remaining for the 10 fresh
    // (never-logged) candidates.
    expect(state.cards.length, 6);
    expect(state.newCardLimitReached, isTrue);
  });

  test('extraNewCardBudgetProvider unlocks additional new cards on top of '
      'the daily cap', () async {
    for (var i = 0; i < 15; i++) {
      await addNewCard('-$i');
    }
    await makeContainer(
      prefsValues: {AppConstants.maxNewCardsPerDayKey: 10},
    );
    container.read(extraNewCardBudgetProvider.notifier).addBatch(5);

    final state =
        await container.read(studySessionProvider(deckId).future);

    expect(state.cards.length, 15);
    expect(state.newCardLimitReached, isFalse);
  });

  test('due review cards are capped at the configured daily maximum',
      () async {
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      final cardId = await addNewCard('-due-$i');
      await cards.updateCardSrs(
        id: cardId,
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 1,
        nextReview: now.subtract(const Duration(minutes: 1)),
        lastReviewed: now,
      );
    }
    await makeContainer(
      prefsValues: {
        AppConstants.maxReviewsPerDayKey: 2,
        AppConstants.maxNewCardsPerDayKey: 0,
      },
    );

    final state =
        await container.read(studySessionProvider(deckId).future);

    expect(state.cards.length, 2);
    expect(state.reviewLimitReached, isTrue);
  });

  // Regression: a failed card (rating < 3) got repetitions=0 / interval=1,
  // which neither the due query (repetitions > 0) nor the new-card filter
  // (intervalDays == 0) matched — so it never came back.
  test('a card rated Again is no longer new and comes back once due', () async {
    final cardId = await addNewCard('-again');
    await makeContainer();
    final sub = container.listen(studySessionProvider(deckId), (_, _) {});
    addTearDown(sub.close);

    await container.read(studySessionProvider(deckId).future);
    await container.read(studySessionProvider(deckId).notifier).submitRating(0);

    final card = (await cards.getCardById(cardId))!;
    expect(card.repetitions, 0);
    expect(card.intervalDays, 1);
    expect(card.isNew, isFalse);

    final now = DateTime.now();
    expect(card.isDue(now), isFalse);
    final tomorrow = now.add(const Duration(days: 1, minutes: 1));
    expect(card.isDue(tomorrow), isTrue);
    expect(
      (await cards.getDueCards(deckId, tomorrow)).map((c) => c.id),
      contains(cardId),
    );
    expect(
      (await cards.getAllDueCards(tomorrow)).map((c) => c.id),
      contains(cardId),
    );
  });

  test(
    'a failed card that is due again is studied as a review, not new',
    () async {
      final now = DateTime.now();
      final cardId = await addNewCard('-lapsed');
      await cards.updateCardSrs(
        id: cardId,
        easeFactor: 1.7,
        intervalDays: 1,
        repetitions: 0,
        nextReview: now.subtract(const Duration(minutes: 1)),
        lastReviewed: now.subtract(const Duration(days: 1)),
      );
      // No new-card budget at all: the card must still be offered as a review.
      await makeContainer(prefsValues: {AppConstants.maxNewCardsPerDayKey: 0});

      final state = await container.read(studySessionProvider(deckId).future);

      expect(state.cards.map((c) => c.id), [cardId]);
    },
  );

  // Regression: the provider wasn't autoDispose, so re-entering study showed
  // the previous session's summary even after new cards had been added.
  test(
    'leaving a finished session drops it, so re-entering starts fresh',
    () async {
      await addNewCard('-first');
      await makeContainer();

      var sub = container.listen(studySessionProvider(deckId), (_, _) {});
      await container.read(studySessionProvider(deckId).future);
      await container
          .read(studySessionProvider(deckId).notifier)
          .submitRating(4);
      expect(
        container.read(studySessionProvider(deckId)).value!.finished,
        isTrue,
      );

      sub.close();
      await container.pump();

      await addNewCard('-added-later');
      sub = container.listen(studySessionProvider(deckId), (_, _) {});
      addTearDown(sub.close);
      final state = await container.read(studySessionProvider(deckId).future);

      expect(state.finished, isFalse);
      expect(state.cards.map((c) => c.sourceText), ['word-added-later']);
    },
  );
}
