import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

class DecksRepository {
  DecksRepository(this._db);

  final AppDatabase _db;

  Stream<List<Deck>> watchAllDecks() => _db.select(_db.decks).watch();

  Stream<Deck?> watchDeckById(int id) => (_db.select(
    _db.decks,
  )..where((d) => d.id.equals(id))).watchSingleOrNull();

  Future<Deck?> getDeckById(int id) =>
      (_db.select(_db.decks)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<int> createDeck(DecksCompanion deck) =>
      _db.into(_db.decks).insert(deck);

  /// Updates a deck's editable fields. The source and target languages are
  /// fixed when the deck is created — changing them would relabel every card
  /// already in the deck — so they are deliberately not updatable here.
  Future<void> updateDeckDetails({
    required int id,
    required String name,
    required String? description,
    required DateTime updatedAt,
  }) async {
    await (_db.update(_db.decks)..where((d) => d.id.equals(id))).write(
      DecksCompanion(
        name: Value(name),
        description: Value(description),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<int> deleteDeck(int id) =>
      (_db.delete(_db.decks)..where((d) => d.id.equals(id))).go();
}

final decksRepositoryProvider = Provider<DecksRepository>((ref) {
  return DecksRepository(ref.watch(appDatabaseProvider));
});
