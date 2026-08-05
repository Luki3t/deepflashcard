import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cards/add_card_screen.dart';
import '../../features/decks/deck_detail_screen.dart';
import '../../features/decks/decks_screen.dart';
import '../../features/onboarding/confirm_screen.dart';
import '../../features/onboarding/language_preferences_provider.dart';
import '../../features/onboarding/language_selection_screen.dart';
import '../../features/onboarding/model_download_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/credits_licenses_screen.dart';
import '../../features/settings/import_csv_screen.dart';
import '../../features/settings/sentence_packs_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/study/mode_selection_screen.dart';
import '../../features/study/multiple_choice_screen.dart';
import '../../features/study/study_screen.dart';
import '../../features/study/typing_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<bool>(onboardingCompletedProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final done = _ref.read(onboardingCompletedProvider);
    final onOnboarding = state.matchedLocation.startsWith('/onboarding');
    if (!done && !onOnboarding) return '/onboarding/welcome';
    if (done && onOnboarding) return '/';
    return null;
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  final router = GoRouter(
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Onboarding ───────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding/welcome',
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/native',
        builder: (_, _) => const LanguageSelectionScreen(isNative: true),
      ),
      GoRoute(
        path: '/onboarding/target',
        builder: (_, _) => const LanguageSelectionScreen(isNative: false),
      ),
      GoRoute(
        path: '/onboarding/confirm',
        builder: (_, _) => const ConfirmScreen(),
      ),
      GoRoute(
        path: '/onboarding/download',
        builder: (_, _) => const ModelDownloadScreen(),
      ),
      GoRoute(
        path: '/language-packs',
        builder: (_, _) => const ModelDownloadScreen(),
      ),

      // ── Full-screen settings ──────────────────────────────────────────
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/sentence-packs',
        builder: (_, _) => const SentencePacksScreen(),
      ),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(
        path: '/credits-licenses',
        builder: (_, _) => const CreditsLicensesScreen(),
      ),
      GoRoute(path: '/import-csv', builder: (_, _) => const ImportCsvScreen()),

      // ── Global study (full-screen, no bottom nav) ─────────────────────
      // /study/all → mode selection entry point (inside shell, see below)
      // The actual study sessions are outside the shell to avoid key conflicts.
      GoRoute(
        path: '/study/flip',
        builder: (_, _) => const StudyScreen(deckId: null),
      ),
      GoRoute(
        path: '/study/choice',
        builder: (_, _) => const MultipleChoiceScreen(deckId: null),
      ),
      GoRoute(
        path: '/study/typing',
        builder: (_, _) => const TypingScreen(deckId: null),
      ),

      // ── Deck detail & card routes (full-screen, no bottom nav) ────────
      GoRoute(
        path: '/decks/:id',
        builder: (_, state) =>
            DeckDetailScreen(deckId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'add-card',
            builder: (_, state) =>
                AddCardScreen(deckId: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'edit-card/:cardId',
            builder: (_, state) => AddCardScreen(
              deckId: int.parse(state.pathParameters['id']!),
              editCardId: int.parse(state.pathParameters['cardId']!),
            ),
          ),
          GoRoute(
            path: 'mode',
            builder: (_, state) => ModeSelectionScreen(
              deckId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'study',
            builder: (_, state) =>
                StudyScreen(deckId: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'study/choice',
            builder: (_, state) => MultipleChoiceScreen(
              deckId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'study/typing',
            builder: (_, state) =>
                TypingScreen(deckId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),

      // ── Main shell with bottom nav ────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DecksScreen()),
          GoRoute(
            path: '/study/all',
            builder: (_, _) => const ModeSelectionScreen(deckId: null),
          ),
          GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  final String location;
  final Widget child;

  int get _selectedIndex {
    if (location.startsWith('/study')) return 1;
    if (location.startsWith('/stats')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/study/all');
            case 2:
              context.go('/stats');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Decks',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Study',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
