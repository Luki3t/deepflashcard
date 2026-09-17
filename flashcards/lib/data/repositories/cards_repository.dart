import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

class CardsRepository {
  CardsRepository(this._db);

  final AppDatabase _db;

  Stream<List<FlashCard>> watchCardsForDeck(int deckId) =>
      (_db.select(_db.cards)..where((c) => c.deckId.equals(deckId))).watch();

  Future<FlashCard?> getCardById(int id) =>
      (_db.select(_db.cards)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> createCard(CardsCompanion card) =>
      _db.into(_db.cards).insert(card);

  Future<void> insertCardsBatch(List<CardsCompanion> cards) async {
    await _db.batch((batch) => batch.insertAll(_db.cards, cards));
  }

  Future<bool> updateCard(CardsCompanion card) =>
      _db.update(_db.cards).replace(card);

  Future<int> deleteCard(int id) =>
      (_db.delete(_db.cards)..where((c) => c.id.equals(id))).go();

  Future<List<FlashCard>> getAllCards() => _db.select(_db.cards).get();

  Future<List<FlashCard>> getAllDueCards(DateTime now) =>
      (_db.select(_db.cards)..where(
            (c) =>
                c.nextReview.isSmallerOrEqualValue(now) &
                c.intervalDays.isBiggerThanValue(0),
          ))
          .get();

  Future<void> updateCardSrs({
    required int id,
    required double easeFactor,
    required int intervalDays,
    required int repetitions,
    required DateTime nextReview,
    required DateTime lastReviewed,
  }) async {
    await (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        easeFactor: Value(easeFactor),
        intervalDays: Value(intervalDays),
        repetitions: Value(repetitions),
        nextReview: Value(nextReview),
        lastReviewed: Value(lastReviewed),
      ),
    );
  }

  Future<void> updateCardText({
    required int id,
    required String sourceText,
    required String targetText,
    required String? notes,
    String? exampleSentence,
    String? exampleTranslation,
  }) async {
    await (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        sourceText: Value(sourceText),
        targetText: Value(targetText),
        notes: Value(notes),
        exampleSentence: Value(exampleSentence),
        exampleTranslation: Value(exampleTranslation),
      ),
    );
  }

  Future<List<FlashCard>> getDueCards(int deckId, DateTime now) =>
      (_db.select(_db.cards)..where(
            (c) =>
                c.deckId.equals(deckId) &
                c.nextReview.isSmallerOrEqualValue(now) &
                c.intervalDays.isBiggerThanValue(0),
          ))
          .get();
}

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepository(ref.watch(appDatabaseProvider));
});
