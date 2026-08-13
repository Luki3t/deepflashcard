import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

class ReviewsRepository {
  ReviewsRepository(this._db);

  final AppDatabase _db;

  Future<int> logReview(ReviewLogsCompanion review) =>
      _db.into(_db.reviewLogs).insert(review);

  Future<List<ReviewLog>> getReviewsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.reviewLogs)..where(
          (r) =>
              r.reviewedAt.isBiggerOrEqualValue(start) &
              r.reviewedAt.isSmallerThanValue(end),
        ))
        .get();
  }

  Future<List<ReviewLog>> getReviewsInRange(DateTime start, DateTime end) =>
      (_db.select(_db.reviewLogs)..where(
            (r) =>
                r.reviewedAt.isBiggerOrEqualValue(start) &
                r.reviewedAt.isSmallerThanValue(end),
          ))
          .get();

  // Cards logged with previousInterval == 0 were on their very first review
  // (brand-new cards default to intervalDays 0), so this counts new cards
  // introduced on the given date — used to enforce the daily new-card cap.
  Future<int> countNewCardsIntroduced(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows =
        await (_db.select(_db.reviewLogs)..where(
              (r) =>
                  r.reviewedAt.isBiggerOrEqualValue(start) &
                  r.reviewedAt.isSmallerThanValue(end) &
                  r.previousInterval.equals(0),
            ))
            .get();
    return rows.map((r) => r.cardId).toSet().length;
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref.watch(appDatabaseProvider));
});
