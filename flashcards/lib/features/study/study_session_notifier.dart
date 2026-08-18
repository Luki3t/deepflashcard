import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/cards_repository.dart';
import '../../data/repositories/reviews_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../stats/stats_providers.dart';
import 'srs_algorithm.dart';

class SessionStats {
  const SessionStats({this.reviewed = 0, this.correct = 0, this.again = 0});

  final int reviewed;
  final int correct;
  final int again;

  SessionStats copyWith({int? reviewed, int? correct, int? again}) =>
      SessionStats(
        reviewed: reviewed ?? this.reviewed,
        correct: correct ?? this.correct,
        again: again ?? this.again,
      );
}

class StudySessionState {
  const StudySessionState({
    required this.cards,
    required this.index,
    required this.stats,
    this.finished = false,
    this.newCardLimitReached = false,
    this.reviewLimitReached = false,
  });

  final List<FlashCard> cards;
  final int index;
  final SessionStats stats;
  final bool finished;
  // True when there are still unstudied new cards waiting, but today's
  // "max new cards per day" budget is used up.
  final bool newCardLimitReached;
  // True when there are still due cards waiting, but today's
  // "max reviews per day" budget is used up.
  final bool reviewLimitReached;

  FlashCard? get currentCard => index < cards.length ? cards[index] : null;

  double get progress => cards.isEmpty ? 1.0 : index / cards.length;
}

// Lets the user manually unlock one more batch of new cards today, on top
// of the configured daily cap, without changing the persisted setting.
// Lives only in memory (not persisted), so it naturally resets on app
// restart.
class ExtraNewCardBudgetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void addBatch(int amount) => state += amount;
}

final extraNewCardBudgetProvider =
    NotifierProvider<ExtraNewCardBudgetNotifier, int>(
      ExtraNewCardBudgetNotifier.new,
    );

// Same idea as ExtraNewCardBudgetNotifier, but for unlocking one more batch
// of due-card reviews once the "max reviews per day" budget is used up.
class ExtraReviewBudgetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void addBatch(int amount) => state += amount;
}

final extraReviewBudgetProvider =
    NotifierProvider<ExtraReviewBudgetNotifier, int>(
      ExtraReviewBudgetNotifier.new,
    );

// In Riverpod 3.x: notifier extends AsyncNotifier<T>,
// arg is passed through the factory function.
class StudySessionNotifier extends AsyncNotifier<StudySessionState> {
  StudySessionNotifier(this.deckId);
  final int? deckId;

  @override
  Future<StudySessionState> build() async {
    final now = DateTime.now();
    final cardsRepo = ref.read(cardsRepositoryProvider);
    final reviewsRepo = ref.read(reviewsRepositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final maxNew =
        prefs.getInt(AppConstants.maxNewCardsPerDayKey) ??
        AppConstants.defaultMaxNewCardsPerDay;
    final maxReviews =
        prefs.getInt(AppConstants.maxReviewsPerDayKey) ??
        AppConstants.defaultMaxReviewsPerDay;
    final introducedToday = await reviewsRepo.countNewCardsIntroduced(now);
    final reviewedToday = await reviewsRepo.countDueCardsReviewed(now);
    final extraBudget = ref.read(extraNewCardBudgetProvider);
    final extraReviewBudget = ref.read(extraReviewBudgetProvider);
    final newCardBudget =
        (maxNew - introducedToday).clamp(0, maxNew).toInt() + extraBudget;
    final reviewBudget =
        (maxReviews - reviewedToday).clamp(0, maxReviews).toInt() +
        extraReviewBudget;

    final List<FlashCard> due;
    final List<FlashCard> all;

    if (deckId != null) {
      due = await cardsRepo.getDueCards(deckId!, now);
      all = await cardsRepo.watchCardsForDeck(deckId!).first;
    } else {
      due = await cardsRepo.getAllDueCards(now);
      all = await cardsRepo.getAllCards();
    }

    final dueCards = due.take(reviewBudget).toList();
    final reviewLimitReached = dueCards.length < due.length;

    final dueIds = due.map((c) => c.id).toSet();
    final newCandidates = all.where(
      (c) =>
          c.repetitions == 0 && c.intervalDays == 0 && !dueIds.contains(c.id),
    );
    final newCards = newCandidates.take(newCardBudget).toList();
    final newCardLimitReached = newCards.length < newCandidates.length;

    return StudySessionState(
      cards: [...dueCards, ...newCards],
      index: 0,
      stats: const SessionStats(),
      newCardLimitReached: newCardLimitReached,
      reviewLimitReached: reviewLimitReached,
    );
  }

  Future<void> submitRating(int rating) async {
    final current = state.value;
    if (current == null || current.currentCard == null) return;

    final card = current.currentCard!;
    final now = DateTime.now();
    final result = applySM2(card, rating, now);

    await ref
        .read(cardsRepositoryProvider)
        .updateCardSrs(
          id: card.id,
          easeFactor: result.easeFactor,
          intervalDays: result.intervalDays,
          repetitions: result.repetitions,
          nextReview: result.nextReview,
          lastReviewed: now,
        );

    await ref
        .read(reviewsRepositoryProvider)
        .logReview(
          ReviewLogsCompanion.insert(
            cardId: card.id,
            reviewedAt: now,
            rating: rating,
            previousInterval: card.intervalDays,
            newInterval: result.intervalDays,
          ),
        );

    ref.invalidate(todayProgressProvider);
    ref.invalidate(statsDataProvider);

    final newStats = current.stats.copyWith(
      reviewed: current.stats.reviewed + 1,
      correct: rating >= 3 ? current.stats.correct + 1 : current.stats.correct,
      again: rating == 0 ? current.stats.again + 1 : current.stats.again,
    );

    final nextIndex = current.index + 1;
    final finished = nextIndex >= current.cards.length;

    if (finished) {
      final statsRepo = ref.read(statsRepositoryProvider);
      await statsRepo.updateStreak(now);
      await statsRepo.incrementTotalReviews(newStats.reviewed);
    }

    state = AsyncData(
      StudySessionState(
        cards: current.cards,
        index: nextIndex,
        stats: newStats,
        finished: finished,
      ),
    );
  }
}

final studySessionProvider =
    AsyncNotifierProvider.family<StudySessionNotifier, StudySessionState, int?>(
      (deckId) => StudySessionNotifier(deckId),
    );
