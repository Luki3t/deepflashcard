import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/decks_repository.dart';
import '../../services/tts_service.dart';
import 'srs_algorithm.dart';
import 'study_session_notifier.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key, required this.deckId});
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
        return _StudyView(session: session, deckId: deckId);
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

class _StudyView extends ConsumerStatefulWidget {
  const _StudyView({required this.session, required this.deckId});
  final StudySessionState session;
  final int? deckId;

  @override
  ConsumerState<_StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends ConsumerState<_StudyView>
    with SingleTickerProviderStateMixin {
  bool _flipped = false;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_StudyView old) {
    super.didUpdateWidget(old);
    if (old.session.index != widget.session.index) {
      _flipped = false;
      _flipController.reset();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipped) return;
    setState(() => _flipped = true);
    _flipController.forward();
    _autoSpeak();
  }

  Future<void> _autoSpeak() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!(prefs.getBool(AppConstants.autoPlayTtsKey) ?? false)) return;
    final card = ref
        .read(studySessionProvider(widget.deckId))
        .value
        ?.currentCard;
    if (card == null) return;
    final deck = await ref
        .read(decksRepositoryProvider)
        .getDeckById(card.deckId);
    if (deck == null) return;
    ref.read(ttsServiceProvider).speak(card.targetText, deck.targetLanguage);
  }

  Future<void> _rate(int rating) async {
    await ref
        .read(studySessionProvider(widget.deckId).notifier)
        .submitRating(rating);
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
                Icon(Icons.check, color: Colors.green, size: 18),
                Text(' ${session.stats.correct}  '),
                Icon(Icons.close, color: Colors.red, size: 18),
                Text(' ${session.stats.again}'),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: session.progress),
          Expanded(
            child: GestureDetector(
              onTap: _flip,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _FlipCard(
                  animation: _flipAnimation,
                  card: card,
                  flipped: _flipped,
                  deckId: widget.deckId,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _flipped
                ? _RatingButtons(card: card, onRate: _rate)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      'Tap card to reveal',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FlipCard extends ConsumerWidget {
  const _FlipCard({
    required this.animation,
    required this.card,
    required this.flipped,
    required this.deckId,
  });

  final Animation<double> animation;
  final FlashCard card;
  final bool flipped;
  final int? deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final angle = animation.value * pi;
        final showBack = angle > pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _CardFace(
                    text: card.targetText,
                    subText: card.notes,
                    isBack: true,
                    deckId: deckId,
                    cardId: card.id,
                    exampleSentence: card.exampleSentence,
                    exampleTranslation: card.exampleTranslation,
                  ),
                )
              : _CardFace(text: card.sourceText, isBack: false),
        );
      },
    );
  }
}

class _CardFace extends ConsumerWidget {
  const _CardFace({
    required this.text,
    required this.isBack,
    this.subText,
    this.deckId,
    this.cardId,
    this.exampleSentence,
    this.exampleTranslation,
  });

  final String text;
  final String? subText;
  final bool isBack;
  final int? deckId;
  final int? cardId;
  final String? exampleSentence;
  final String? exampleTranslation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBack)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Translation',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Text(
                text,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              if (isBack && deckId != null)
                FutureBuilder(
                  future: ref
                      .read(decksRepositoryProvider)
                      .getDeckById(deckId!),
                  builder: (context, snap) {
                    final deck = snap.data;
                    if (deck == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: IconButton(
                        icon: const Icon(Icons.volume_up_outlined),
                        tooltip: 'Listen',
                        onPressed: () async {
                          final ok = await ref
                              .read(ttsServiceProvider)
                              .speak(text, deck.targetLanguage);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Voice not available for this language.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              if (subText != null && subText!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  subText!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (exampleSentence != null && exampleSentence!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 4),
                Text(
                  exampleSentence!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (exampleTranslation != null &&
                    exampleTranslation!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exampleTranslation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingButtons extends StatelessWidget {
  const _RatingButtons({required this.card, required this.onRate});

  final FlashCard card;
  final Future<void> Function(int) onRate;

  @override
  Widget build(BuildContext context) {
    final ratings = [
      (0, 'Again', Colors.red),
      (3, 'Hard', Colors.orange),
      (4, 'Good', Colors.green),
      (5, 'Easy', Colors.blue),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        children: ratings.map((r) {
          final (rating, label, color) = r;
          final preview = applySM2(card, rating, DateTime.now());
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _RatingButton(
                label: label,
                interval: formatInterval(preview.intervalDays),
                color: color,
                onTap: () => onRate(rating),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String interval;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.08),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              interval,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
  });
  final SessionStats stats;
  final int? deckId;
  final int totalCards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                ] else
                  Text(
                    'No cards are due right now. Come back later!',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(studySessionProvider(deckId));
                  },
                  child: const Text('Study Again'),
                ),
                if (totalCards > 0) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      ref
                          .read(studySessionProvider(deckId).notifier)
                          .repeatSession();
                    },
                    child: const Text('Repeat This Session'),
                  ),
                ],
                const SizedBox(height: 12),
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
