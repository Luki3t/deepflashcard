import 'app_database.dart';

// A card is "new" until its first review. Every SM-2 outcome — including a
// failed "Again" that resets repetitions to 0 — sets intervalDays to at least
// 1, so intervalDays (not repetitions) is what tells new cards apart from
// cards that are already in the review cycle.
extension FlashCardStatus on FlashCard {
  bool get isNew => intervalDays == 0;

  bool isDue(DateTime now) => !isNew && !nextReview.isAfter(now);
}
