import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Name of the deck detail route, used to find it in the navigator stack.
const deckRouteName = 'deck';

/// Leaves a finished study session for the deck (or the deck list) that the
/// summary's "Back to Deck(s)" button promises. Study screens are pushed on
/// top of the mode-selection screen, so a plain pop would land there instead.
void leaveStudySession(BuildContext context, int? deckId) {
  final router = GoRouter.of(context);
  if (deckId == null) {
    router.go('/');
    return;
  }
  var deckFound = false;
  Navigator.of(context).popUntil((route) {
    if (route.settings.name == deckRouteName) deckFound = true;
    return deckFound || route.isFirst;
  });
  if (!deckFound) router.go('/decks/$deckId');
}
