import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/string_utils.dart';
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
  _AnswerState _state = _AnswerState.idle;

  @override
  void didUpdateWidget(_TypingView old) {
    super.didUpdateWidget(old);
    if (old.session.index != widget.session.index) {
      _controller.clear();
      setState(() => _state = _AnswerState.idle);
    }
  }

  @override
  void dispose() {
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
  }

  void _showAnswer() {
    setState(() => _state = _AnswerState.wrong);
  }

  Future<void> _rate5() => _rate(5);

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
              autofocus: true,
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
                        flex: 2,
                        child: FilledButton(
                          onPressed: _controller.text.trim().isEmpty
                              ? null
                              : _submit,
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

class _SummaryScreen extends StatelessWidget {
  const _SummaryScreen({
    required this.stats,
    required this.deckId,
    required this.totalCards,
  });
  final SessionStats stats;
  final int? deckId;
  final int totalCards;

  @override
  Widget build(BuildContext context) {
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
                  totalCards == 0 ? 'Nothing to study!' : 'Session complete!',
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
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
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
