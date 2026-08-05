import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  Future<UserStat?> getStats() => (_db.select(
    _db.userStats,
  )..where((s) => s.id.equals(1))).getSingleOrNull();

  Future<void> updateStreak(DateTime today) async {
    final stats = await getStats();
    if (stats == null) return;

    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = stats.lastStudyDate != null
        ? DateTime(
            stats.lastStudyDate!.year,
            stats.lastStudyDate!.month,
            stats.lastStudyDate!.day,
          )
        : null;

    if (lastDate == todayDate) return; // already studied today

    final int newStreak;
    if (lastDate == todayDate.subtract(const Duration(days: 1))) {
      newStreak = stats.currentStreak + 1; // extend streak
    } else {
      newStreak = 1; // streak broken or first session
    }

    await (_db.update(_db.userStats)..where((s) => s.id.equals(1))).write(
      UserStatsCompanion(
        currentStreak: Value(newStreak),
        longestStreak: Value(max(newStreak, stats.longestStreak)),
        lastStudyDate: Value(today),
      ),
    );
  }

  Future<void> incrementTotalReviews(int count) async {
    final stats = await getStats();
    if (stats == null) return;
    await (_db.update(_db.userStats)..where((s) => s.id.equals(1))).write(
      UserStatsCompanion(totalReviews: Value(stats.totalReviews + count)),
    );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(appDatabaseProvider));
});
