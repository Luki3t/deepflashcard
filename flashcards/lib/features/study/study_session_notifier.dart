import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/cards_repository.dart';
import '../../data/repositories/reviews_repository.dart';
import '../../data/repositories/stats_repository.dart';
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
  });

  final List<FlashCard> cards;
  final int index;
  final SessionStats stats;
  final bool finished;

  FlashCard? get currentCard => index < cards.length ? cards[index] : null;

  double get progress => cards.isEmpty ? 1.0 : index / cards.length;
}

// In Riverpod 3.x: notifier extends AsyncNotifier<T>,
// arg is passed through the factory function.
class StudySessionNotifier extends AsyncNotifier<StudySessionState> {
  StudySessionNotifier(this.deckId);
  final int? deckId;

  @override
  Future<StudySessionState> build() async {
    final now = DateTime.now();
    final cardsRepo = ref.read(cardsRepositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final maxNew =
        prefs.getInt(AppConstants.maxNewCardsPerDayKey) ??
        AppConstants.defaultMaxNewCardsPerDay;

    final List<FlashCard> due;
    final List<FlashCard> all;

    if (deckId != null) {
      due = await cardsRepo.getDueCards(deckId!, now);
      all = await cardsRepo.watchCardsForDeck(deckId!).first;
    } else {
      due = await cardsRepo.getAllDueCards(now);
      all = await cardsRepo.getAllCards();
    }

    final dueIds = due.map((c) => c.id).toSet();
    final newCards = all
        .where(
          (c) =>
              c.repetitions == 0 &&
              c.intervalDays == 0 &&
              !dueIds.contains(c.id),
        )
        .take(maxNew)
        .toList();

    return StudySessionState(
      cards: [...due, ...newCards],
      index: 0,
      stats: const SessionStats(),
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

  void repeatSession() {
    final current = state.value;
    if (current == null || current.cards.isEmpty) return;
    final cards = List.of(current.cards)..shuffle();
    state = AsyncData(
      StudySessionState(cards: cards, index: 0, stats: const SessionStats()),
    );
  }
}

final studySessionProvider =
    AsyncNotifierProvider.family<StudySessionNotifier, StudySessionState, int?>(
      (deckId) => StudySessionNotifier(deckId),
    );
