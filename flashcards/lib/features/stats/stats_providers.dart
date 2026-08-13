import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/cards_repository.dart';
import '../../data/repositories/decks_repository.dart';
import '../../data/repositories/reviews_repository.dart';
import '../../data/repositories/stats_repository.dart';

class DeckProgress {
  const DeckProgress({
    required this.deck,
    required this.total,
    required this.learned,
  });
  final Deck deck;
  final int total;
  final int learned;

  double get ratio => total == 0 ? 0 : learned / total;
}

class StatsData {
  const StatsData({
    required this.userStat,
    required this.totalCards,
    required this.dueNow,
    required this.learnedCards,
    required this.deckProgress,
    required this.activityMap,
    required this.reviewedToday,
  });

  final UserStat? userStat;
  final int totalCards;
  final int dueNow;
  final int learnedCards;
  final List<DeckProgress> deckProgress;
  // date (midnight) → number of reviews
  final Map<DateTime, int> activityMap;
  final int reviewedToday;
}

final statsDataProvider = FutureProvider.autoDispose<StatsData>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final ninetyDaysAgo = today.subtract(const Duration(days: 89));

  final cardsRepo = ref.read(cardsRepositoryProvider);
  final decksRepo = ref.read(decksRepositoryProvider);
  final reviewsRepo = ref.read(reviewsRepositoryProvider);
  final statsRepo = ref.read(statsRepositoryProvider);

  final allCards = await cardsRepo.getAllCards();
  final allDecks = await decksRepo.watchAllDecks().first;
  final recentReviews = await reviewsRepo.getReviewsInRange(ninetyDaysAgo, now);
  final todayReviews = await reviewsRepo.getReviewsForDate(today);
  final userStat = await statsRepo.getStats();

  // Activity map: date → count of reviews
  final activityMap = <DateTime, int>{};
  for (final r in recentReviews) {
    final d = DateTime(r.reviewedAt.year, r.reviewedAt.month, r.reviewedAt.day);
    activityMap[d] = (activityMap[d] ?? 0) + 1;
  }

  // Per-deck progress
  final deckProgress = <DeckProgress>[];
  for (final deck in allDecks) {
    final cards = allCards.where((c) => c.deckId == deck.id).toList();
    deckProgress.add(
      DeckProgress(
        deck: deck,
        total: cards.length,
        learned: cards.where((c) => c.repetitions >= 3).length,
      ),
    );
  }

  return StatsData(
    userStat: userStat,
    totalCards: allCards.length,
    dueNow: allCards
        .where((c) => !c.nextReview.isAfter(now) && c.repetitions > 0)
        .length,
    learnedCards: allCards.where((c) => c.repetitions >= 3).length,
    deckProgress: deckProgress,
    activityMap: activityMap,
    reviewedToday: todayReviews
        .map((r) => r.cardId)
        .toSet()
        .length, // distinct cards reviewed
  );
});

// Lightweight provider for the "Today" banner on the Decks screen.
final todayProgressProvider =
    FutureProvider.autoDispose<({int reviewed, int due})>((ref) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final cardsRepo = ref.read(cardsRepositoryProvider);
      final reviewsRepo = ref.read(reviewsRepositoryProvider);

      final allCards = await cardsRepo.getAllCards();
      final due = allCards
          .where((c) => !c.nextReview.isAfter(now) && c.repetitions > 0)
          .length;
      if (due == 0) return (reviewed: 0, due: 0);

      final todayReviews = await reviewsRepo.getReviewsForDate(today);
      final reviewed = todayReviews.map((r) => r.cardId).toSet().length;

      return (reviewed: reviewed, due: due);
    });
