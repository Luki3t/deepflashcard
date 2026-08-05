import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Decks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get sourceLanguage => text()();
  TextColumn get targetLanguage => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('FlashCard')
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deckId =>
      integer().references(Decks, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceText => text()();
  TextColumn get targetText => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextReview => dateTime()();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  TextColumn get exampleSentence => text().nullable()();
  TextColumn get exampleTranslation => text().nullable()();
}

class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get reviewedAt => dateTime()();
  IntColumn get rating => integer()();
  IntColumn get previousInterval => integer()();
  IntColumn get newInterval => integer()();
}

class UserStats extends Table {
  IntColumn get id => integer()();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastStudyDate => dateTime().nullable()();
  IntColumn get totalReviews => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Decks, Cards, ReviewLogs, UserStats])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(userStats).insert(const UserStatsCompanion(id: Value(1)));
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          'ALTER TABLE cards ADD COLUMN example_sentence TEXT',
        );
        await customStatement(
          'ALTER TABLE cards ADD COLUMN example_translation TEXT',
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'flashcards');
}
