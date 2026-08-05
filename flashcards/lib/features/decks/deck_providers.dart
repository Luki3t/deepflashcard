import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/cards_repository.dart';
import '../../data/repositories/decks_repository.dart';

final watchAllDecksProvider = StreamProvider<List<Deck>>((ref) {
  return ref.watch(decksRepositoryProvider).watchAllDecks();
});

final watchDeckProvider = StreamProvider.family<Deck?, int>((ref, id) {
  return ref.watch(decksRepositoryProvider).watchDeckById(id);
});

final watchCardsForDeckProvider = StreamProvider.family<List<FlashCard>, int>((
  ref,
  deckId,
) {
  return ref.watch(cardsRepositoryProvider).watchCardsForDeck(deckId);
});
