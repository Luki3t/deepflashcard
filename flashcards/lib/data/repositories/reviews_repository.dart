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
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref.watch(appDatabaseProvider));
});
