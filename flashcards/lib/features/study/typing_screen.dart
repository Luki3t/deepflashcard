import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../core/utils/string_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/decks_repository.dart';
import '../../services/tts_service.dart';
import 'study_navigation.dart';
import 'study_session_notifier.dart';

enum _AnswerState { idle, correct, partial, wrong }

class TypingScreen extends ConsumerWidget {
  const TypingScreen({super.key, required this.deckId});
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
        return _TypingView(session: session, deckId: deckId);
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

class _TypingView extends ConsumerStatefulWidget {
  const _TypingView({required this.session, required this.deckId});
  final StudySessionState session;
  final int? deckId;

  @override
  ConsumerState<_TypingView> createState() => _TypingViewState();
}

class _TypingViewState extends ConsumerState<_TypingView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  _AnswerState _state = _AnswerState.idle;
  int _hintLetters = 0;

  @override
  void didUpdateWidget(_TypingView old) {
    super.didUpdateWidget(old);
    if (old.session.index != widget.session.index) {
      _controller.clear();
      setState(() {
        _state = _AnswerState.idle;
        _hintLetters = 0;
      });
      // The field was disabled while the answer was shown, which drops focus
      // (and the keyboard); give it back so the user can type straight away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final session =
        ref.read(studySessionProvider(widget.deckId)).value ?? widget.session;
    final card = session.currentCard!;
    final sim = similarity(_controller.text, card.targetText);

    if (sim >= 1.0) {
      setState(() => _state = _AnswerState.correct);
      Future.delayed(const Duration(milliseconds: 600), _rate5);
    } else if (sim >= 0.8) {
      setState(() => _state = _AnswerState.partial);
    } else {
      setState(() => _state = _AnswerState.wrong);
    }
    _autoSpeak(card);
  }

  void _showAnswer() {
    final session =
        ref.read(studySessionProvider(widget.deckId)).value ?? widget.session;
    final card = session.currentCard!;
    setState(() => _state = _AnswerState.wrong);
    _autoSpeak(card);
  }

  void _revealNextHintLetter(String target) {
    if (_hintLetters >= target.length) return;
    setState(() => _hintLetters++);
  }

  String _hintText(String target) {
    return List.generate(target.length, (i) {
      final ch = target[i];
      if (ch == ' ') return ' ';
      return i < _hintLetters ? ch : '_';
    }).join(' ');
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

  Future<void> _rate5() async {
    if (mounted) await _rate(5);
  }

  Future<void> _rate(int rating) => ref
      .read(studySessionProvider(widget.deckId).notifier)
      .submitRating(rating);

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(studySessionProvider(widget.deckId)).value ?? widget.session;
    final card = session.currentCard;
    if (card == null) return const SizedBox();

    final revealed = _state != _AnswerState.idle;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              // The answer is compared letter by letter, so the keyboard must
              // not "fix" it (e.g. Gboard turning "tree" into "three").
              autocorrect: false,
              enableSuggestions: false,
              enabled: !revealed,
              decoration: InputDecoration(
                hintText: 'Type the translation...',
                border: const OutlineInputBorder(),
                suffixIcon: _state == _AnswerState.correct
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                fillColor: _stateFillColor(context),
                filled: revealed,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!revealed) _submit();
              },
            ),
          ),
          if (!revealed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _hintLetters >= card.targetText.length
                        ? null
                        : () => _revealNextHintLetter(card.targetText),
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Hint'),
                  ),
                  if (_hintLetters > 0)
                    Expanded(
                      child: Text(
                        _hintText(card.targetText),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_state == _AnswerState.partial || _state == _AnswerState.wrong)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: _state == _AnswerState.partial
                    ? Colors.amber.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _state == _AnswerState.partial
                            ? 'Close! The correct answer:'
                            : 'Correct answer:',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.targetText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: !revealed
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showAnswer,
                          child: const Text('Show answer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  )
                : _state == _AnswerState.partial
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rate(3),
                          child: const Text('Hard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _rate(4),
                          child: const Text('I had it'),
                        ),
                      ),
                    ],
                  )
                : _state == _AnswerState.wrong
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rate(4),
                          child: const Text('I had it'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _rate(0),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Got it wrong'),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Color? _stateFillColor(BuildContext context) => switch (_state) {
    _AnswerState.correct => Colors.green.withValues(alpha: 0.08),
    _AnswerState.partial => Colors.amber.withValues(alpha: 0.08),
    _AnswerState.wrong => Colors.red.withValues(alpha: 0.08),
    _AnswerState.idle => null,
  };
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
                    '${countLabel(stats.reviewed, 'card')} reviewed',
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
                  onPressed: () => leaveStudySession(context, deckId),
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
