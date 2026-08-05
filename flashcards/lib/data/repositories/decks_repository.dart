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

  Future<bool> updateDeck(DecksCompanion deck) =>
      _db.update(_db.decks).replace(deck);

  Future<int> deleteDeck(int id) =>
      (_db.delete(_db.decks)..where((d) => d.id.equals(id))).go();
}

final decksRepositoryProvider = Provider<DecksRepository>((ref) {
  return DecksRepository(ref.watch(appDatabaseProvider));
});
