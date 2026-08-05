import 'dart:math';

import '../../data/database/app_database.dart';

class SrsResult {
  const SrsResult({
    required this.intervalDays,
    required this.repetitions,
    required this.easeFactor,
    required this.nextReview,
  });

  final int intervalDays;
  final int repetitions;
  final double easeFactor;
  final DateTime nextReview;
}

SrsResult applySM2(FlashCard card, int rating, DateTime now) {
  assert(rating >= 0 && rating <= 5);

  final int newInterval;
  final int newRepetitions;

  if (rating < 3) {
    // Forgot — reset
    newRepetitions = 0;
    newInterval = 1;
  } else {
    // Recalled
    newRepetitions = card.repetitions + 1;
    if (card.repetitions == 0) {
      newInterval = 1;
    } else if (card.repetitions == 1) {
      newInterval = 6;
    } else {
      newInterval = max(1, (card.intervalDays * card.easeFactor).round());
    }
  }

  final newEF =
      (card.easeFactor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02)))
          .clamp(1.3, 5.0);

  return SrsResult(
    intervalDays: newInterval,
    repetitions: newRepetitions,
    easeFactor: newEF,
    nextReview: now.add(Duration(days: newInterval)),
  );
}

String formatInterval(int days) {
  if (days < 1) return '<1d';
  if (days == 1) return '1d';
  if (days < 30) return '${days}d';
  if (days < 365) return '${(days / 30).round()}mo';
  return '${(days / 365).round()}y';
}
