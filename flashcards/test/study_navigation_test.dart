import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flashcards/features/study/study_navigation.dart';

// Mirrors the app's route shape: study screens are pushed on top of the deck
// and its mode-selection screen, so "Back to Deck" must skip the latter.
GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('Decks')),
    ),
    GoRoute(
      path: '/study/all',
      builder: (_, _) => const Scaffold(body: Text('Global mode')),
    ),
    GoRoute(
      path: '/study/flip',
      builder: (context, _) => _StudyPage(deckId: null),
    ),
    GoRoute(
      path: '/decks/:id',
      name: deckRouteName,
      builder: (_, state) =>
          Scaffold(body: Text('Deck ${state.pathParameters['id']}')),
      routes: [
        GoRoute(
          path: 'mode',
          builder: (_, _) => const Scaffold(body: Text('Mode')),
        ),
        GoRoute(
          path: 'study',
          builder: (_, state) =>
              _StudyPage(deckId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    ),
  ],
);

class _StudyPage extends StatelessWidget {
  const _StudyPage({required this.deckId});
  final int? deckId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => leaveStudySession(context, deckId),
      child: const Text('Back'),
    ),
  );
}

void main() {
  testWidgets('Back to Deck returns to the deck, not the mode selection', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.push('/decks/7');
    await tester.pumpAndSettle();
    router.push('/decks/7/mode');
    await tester.pumpAndSettle();
    router.push('/decks/7/study');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Deck 7'), findsOneWidget);
    expect(find.text('Mode'), findsNothing);

    // The deck list is still underneath, so back from the deck works.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Decks'), findsOneWidget);
  });

  testWidgets('Back to Deck opens the deck when it is not in the stack', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.push('/decks/3/study');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Deck 3'), findsOneWidget);
  });

  testWidgets('Back to Decks from a global session goes to the deck list', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/study/all');
    await tester.pumpAndSettle();
    router.push('/study/flip');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Decks'), findsOneWidget);
    expect(find.text('Global mode'), findsNothing);
  });
}
