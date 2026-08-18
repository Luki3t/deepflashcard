import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/cards_repository.dart';
import '../../data/repositories/decks_repository.dart';
import '../../services/tts_service.dart';
import 'study_session_notifier.dart';

class MultipleChoiceScreen extends ConsumerWidget {
  const MultipleChoiceScreen({super.key, required this.deckId});
  final int? deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(studySessionProvider(deckId));

    return sessionAsync.when(
      data: (session) {
        if (session.finished || session.cards.isEmpty) {
          return _SummaryScreen(
            stats: session.stats,
            deckId: deckId,
            totalCards: session.cards.length,
            newCardLimitReached: session.newCardLimitReached,
            reviewLimitReached: session.reviewLimitReached,
          );
        }
        return _ChoiceView(session: session, deckId: deckId);
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ChoiceView extends ConsumerStatefulWidget {
  const _ChoiceView({required this.session, required this.deckId});
  final StudySessionState session;
  final int? deckId;

  @override
  ConsumerState<_ChoiceView> createState() => _ChoiceViewState();
}

class _ChoiceViewState extends ConsumerState<_ChoiceView> {
  List<FlashCard>? _choices;
  int? _tapped; // index tapped
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _loadChoices();
  }

  @override
  void didUpdateWidget(_ChoiceView old) {
    super.didUpdateWidget(old);
    if (old.session.index != widget.session.index) {
      setState(() {
        _choices = null;
        _tapped = null;
        _revealed = false;
      });
      _loadChoices();
    }
  }

  Future<void> _loadChoices() async {
    final session =
        ref.read(studySessionProvider(widget.deckId)).value ?? widget.session;
    final card = session.currentCard;
    if (card == null) return;

    final cardsRepo = ref.read(cardsRepositoryProvider);
    final List<FlashCard> pool;

    if (widget.deckId != null) {
      pool = await cardsRepo.watchCardsForDeck(widget.deckId!).first;
    } else {
      pool = await cardsRepo.getAllCards();
    }

    final others = pool.where((c) => c.id != card.id).toList()..shuffle();
    final distractors = others.take(3).toList();

    if (distractors.length < 3) {
      // Not enough cards — fall back handled by parent (card count check)
    }

    final choices = [...distractors, card]..shuffle();
    if (mounted) setState(() => _choices = choices);
  }

  Future<void> _tap(int index) async {
    if (_revealed) return;
    final session =
        ref.read(studySessionProvider(widget.deckId)).value ?? widget.session;
    final card = session.currentCard!;
    final tapped = _choices![index];
    final correct = tapped.id == card.id;

    setState(() {
      _tapped = index;
      _revealed = true;
    });

    _autoSpeak(card);

    if (correct) {
      await Future.delayed(const Duration(milliseconds: 500));
      await ref
          .read(studySessionProvider(widget.deckId).notifier)
          .submitRating(4);
    }
    // Wrong: wait for user to tap Continue
  }

  Future<void> _autoSpeak(FlashCard card) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!(prefs.getBool(AppConstants.autoPlayTtsKey) ?? false)) return;
    final deck = await ref
        .read(decksRepositoryProvider)
        .getDeckById(card.deckId);
    if (deck == null) return;
    ref.read(ttsServiceProvider).speak(card.targetText, deck.targetLanguage);
  }

  Future<void> _continue() async {
    await ref
        .read(studySessionProvider(widget.deckId).notifier)
        .submitRating(0);
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(studySessionProvider(widget.deckId)).value ?? widget.session;
    final card = session.currentCard;
    if (card == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text('${session.index + 1} / ${session.cards.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.green, size: 18),
                Text(' ${session.stats.correct}  '),
                const Icon(Icons.close, color: Colors.red, size: 18),
                Text(' ${session.stats.again}'),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: session.progress),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              card.sourceText,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          if (_choices == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _choices!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final choice = _choices![i];
                  final isCorrect = choice.id == card.id;
                  return _ChoiceButton(
                    text: choice.targetText,
                    state: _revealed
                        ? isCorrect
                              ? _ChoiceState.correct
                              : _tapped == i
                              ? _ChoiceState.wrong
                              : _ChoiceState.neutral
                        : _ChoiceState.idle,
                    onTap: () => _tap(i),
                  );
                },
              ),
            ),
          if (_revealed && _tapped != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _choices![_tapped!].id == card.id
                  ? const SizedBox.shrink()
                  : FilledButton(
                      onPressed: _continue,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Continue'),
                    ),
            )
          else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _ChoiceState { idle, correct, wrong, neutral }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String text;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color textColor;

    switch (state) {
      case _ChoiceState.correct:
        bg = Colors.green.withValues(alpha: 0.15);
        border = Colors.green;
        textColor = Colors.green.shade700;
      case _ChoiceState.wrong:
        bg = Colors.red.withValues(alpha: 0.15);
        border = Colors.red;
        textColor = Colors.red.shade700;
      case _ChoiceState.neutral:
        bg = Theme.of(context).colorScheme.surfaceContainerLow;
        border = Theme.of(context).colorScheme.outlineVariant;
        textColor = Theme.of(context).colorScheme.onSurfaceVariant;
      case _ChoiceState.idle:
        bg = Theme.of(context).colorScheme.surfaceContainerLow;
        border = Theme.of(context).colorScheme.outline;
        textColor = Theme.of(context).colorScheme.onSurface;
    }

    return InkWell(
      onTap: state == _ChoiceState.idle ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: textColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SummaryScreen extends ConsumerWidget {
  const _SummaryScreen({
    required this.stats,
    required this.deckId,
    required this.totalCards,
    required this.newCardLimitReached,
    required this.reviewLimitReached,
  });
  final SessionStats stats;
  final int? deckId;
  final int totalCards;
  final bool newCardLimitReached;
  final bool reviewLimitReached;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    final maxNew =
        prefs.getInt(AppConstants.maxNewCardsPerDayKey) ??
        AppConstants.defaultMaxNewCardsPerDay;
    final maxReviews =
        prefs.getInt(AppConstants.maxReviewsPerDayKey) ??
        AppConstants.defaultMaxReviewsPerDay;
    final anyLimitReached = newCardLimitReached || reviewLimitReached;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.celebration,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  totalCards > 0
                      ? 'Session complete!'
                      : anyLimitReached
                      ? 'Daily limit reached'
                      : 'Nothing to study!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (stats.reviewed > 0) ...[
                  Text(
                    '${stats.reviewed} cards reviewed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${stats.correct} correct · ${stats.again} again',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  Text(
                    newCardLimitReached && reviewLimitReached
                        ? "You've reached today's review and new-word limits."
                        : reviewLimitReached
                        ? "You've reached today's review limit."
                        : newCardLimitReached
                        ? "You've reached today's new-word limit."
                        : 'No cards are due right now. Come back later!',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 32),
                if (totalCards > 0) ...[
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(studySessionProvider(deckId));
                    },
                    child: const Text('Learn More'),
                  ),
                  const SizedBox(height: 12),
                ] else if (anyLimitReached) ...[
                  if (reviewLimitReached) ...[
                    OutlinedButton(
                      onPressed: () {
                        ref
                            .read(extraReviewBudgetProvider.notifier)
                            .addBatch(maxReviews);
                        ref.invalidate(studySessionProvider(deckId));
                      },
                      child: Text('Review $maxReviews More'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (newCardLimitReached) ...[
                    OutlinedButton(
                      onPressed: () {
                        ref
                            .read(extraNewCardBudgetProvider.notifier)
                            .addBatch(maxNew);
                        ref.invalidate(studySessionProvider(deckId));
                      },
                      child: Text('Study $maxNew More New'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                TextButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: Text(
                    deckId != null ? 'Back to Deck' : 'Back to Decks',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
