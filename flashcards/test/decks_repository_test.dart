import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:flashcards/data/database/app_database.dart';
import 'package:flashcards/data/repositories/decks_repository.dart';

void main() {
  late AppDatabase db;
  late DecksRepository repo;

  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DecksRepository(db);
  });

  tearDown(() => db.close());

  Future<int> createDeck() {
    final now = DateTime(2026, 1, 1);
    return repo.createDeck(
      DecksCompanion.insert(
        name: 'Reise',
        sourceLanguage: 'de',
        targetLanguage: 'es',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('updateDeckDetails saves the editable fields', () async {
    final id = await createDeck();
    final updatedAt = DateTime(2026, 6, 1);

    await repo.updateDeckDetails(
      id: id,
      name: 'Reise 2',
      description: 'Holiday words',
      updatedAt: updatedAt,
    );

    final deck = await repo.getDeckById(id);
    expect(deck!.name, 'Reise 2');
    expect(deck.description, 'Holiday words');
    expect(deck.updatedAt, updatedAt);
  });

  test('updateDeckDetails leaves the deck languages untouched', () async {
    final id = await createDeck();

    await repo.updateDeckDetails(
      id: id,
      name: 'Reise 2',
      description: null,
      updatedAt: DateTime(2026, 6, 1),
    );

    final deck = await repo.getDeckById(id);
    expect(deck!.sourceLanguage, 'de');
    expect(deck.targetLanguage, 'es');
  });

  test('updateDeckDetails only touches the deck it was given', () async {
    final first = await createDeck();
    final second = await createDeck();

    await repo.updateDeckDetails(
      id: second,
      name: 'Renamed',
      description: null,
      updatedAt: DateTime(2026, 6, 1),
    );

    expect((await repo.getDeckById(first))!.name, 'Reise');
    expect((await repo.getDeckById(second))!.name, 'Renamed');
  });
}
