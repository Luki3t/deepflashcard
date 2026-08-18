import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/shared_preferences_provider.dart';
import '../decks/deck_providers.dart';

enum StudyMode { flip, choice, typing }

extension StudyModeX on StudyMode {
  String get label => switch (this) {
    StudyMode.flip => 'Flip Cards',
    StudyMode.choice => 'Multiple Choice',
    StudyMode.typing => 'Typing',
  };

  String get emoji => switch (this) {
    StudyMode.flip => '🃏',
    StudyMode.choice => '🔤',
    StudyMode.typing => '⌨️',
  };

  String get description => switch (this) {
    StudyMode.flip => 'Tap to reveal the translation',
    StudyMode.choice => 'Pick the correct answer from 4 options',
    StudyMode.typing => 'Type the translation from memory',
  };

  String get prefsKey => name; // 'flip', 'choice', 'typing'
}

String _prefKey(int? deckId) =>
    deckId != null ? 'deck_${deckId}_study_mode' : 'global_study_mode';

StudyMode loadMode(SharedPreferences prefs, int? deckId) {
  final saved = prefs.getString(_prefKey(deckId));
  return StudyMode.values.firstWhere(
    (m) => m.prefsKey == saved,
    orElse: () => StudyMode.flip,
  );
}

class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({super.key, required this.deckId});
  final int? deckId;

  @override
  ConsumerState<ModeSelectionScreen> createState() =>
      _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen> {
  late StudyMode _selected;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _selected = loadMode(prefs, widget.deckId);
  }

  void _select(StudyMode mode) {
    setState(() => _selected = mode);
    ref
        .read(sharedPreferencesProvider)
        .setString(_prefKey(widget.deckId), mode.prefsKey);
  }

  void _start() {
    final id = widget.deckId;
    switch (_selected) {
      case StudyMode.flip:
        context.push(id != null ? '/decks/$id/study' : '/study/flip');
      case StudyMode.choice:
        context.push(id != null ? '/decks/$id/study/choice' : '/study/choice');
      case StudyMode.typing:
        context.push(id != null ? '/decks/$id/study/typing' : '/study/typing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SourceLabel(deckId: widget.deckId),
            const SizedBox(height: 12),
            Text(
              'How do you want to study?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...StudyMode.values.map(
              (mode) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModeCard(
                  mode: mode,
                  selected: _selected == mode,
                  onTap: () => _select(mode),
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SourceLabel extends ConsumerWidget {
  const _SourceLabel({required this.deckId});
  final int? deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme;
    final text = deckId == null
        ? 'Source: All decks'
        : 'Source: ${ref.watch(watchDeckProvider(deckId!)).value?.name ?? '…'}';

    return Row(
      children: [
        Icon(Icons.style_outlined, size: 16, color: color.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final StudyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color.primary : color.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? color.primaryContainer : color.surfaceContainerLow,
        ),
        child: Row(
          children: [
            Text(mode.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected ? color.onPrimaryContainer : null,
                    ),
                  ),
                  Text(
                    mode.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? color.onPrimaryContainer.withValues(alpha: 0.7)
                          : color.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: color.primary),
          ],
        ),
      ),
    );
  }
}
