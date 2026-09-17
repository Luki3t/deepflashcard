import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/tts_service.dart';

import '../../core/constants/languages.dart';
import '../../data/database/app_database.dart';
import '../../data/database/flash_card_status.dart';
import '../../data/repositories/cards_repository.dart';
import '../../data/repositories/decks_repository.dart';
import 'deck_providers.dart';

class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({super.key, required this.deckId});
  final int deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckAsync = ref.watch(watchDeckProvider(deckId));
    final cardsAsync = ref.watch(watchCardsForDeckProvider(deckId));

    return deckAsync.when(
      data: (deck) {
        if (deck == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Deck not found')),
          );
        }
        return _DeckDetailView(deck: deck, cardsAsync: cardsAsync);
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

class _DeckDetailView extends ConsumerWidget {
  const _DeckDetailView({required this.deck, required this.cardsAsync});
  final Deck deck;
  final AsyncValue<List<FlashCard>> cardsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = cardsAsync.value ?? [];
    final now = DateTime.now();
    final dueCount = cards.where((c) => c.isDue(now)).length;
    final newCount = cards.where((c) => c.isNew).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(deck.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => _onMenuAction(context, ref, action),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit deck')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete deck', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _SummaryBar(
            total: cards.length,
            dueCount: dueCount,
            newCount: newCount,
          ),
          if (dueCount > 0 || newCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FilledButton.icon(
                onPressed: () => context.push('/decks/${deck.id}/mode'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Study Now'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          Expanded(
            child: cardsAsync.when(
              data: (_) => cards.isEmpty
                  ? _emptyState(context)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: cards.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          _CardRow(card: cards[i], deck: deck),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/decks/${deck.id}/add-card'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No cards yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first card.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'edit') {
      await _showEditDeckDialog(context, ref);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete deck?'),
          content: Text(
            "Delete '${deck.name}' and all its cards? This cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(decksRepositoryProvider).deleteDeck(deck.id);
        if (context.mounted) context.pop();
      }
    }
  }

  Future<void> _showEditDeckDialog(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditDeckSheet(deck: deck),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.total,
    required this.dueCount,
    required this.newCount,
  });
  final int total;
  final int dueCount;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(label: 'Total', value: '$total'),
          _Stat(label: 'Due', value: '$dueCount', highlight: dueCount > 0),
          _Stat(label: 'New', value: '$newCount'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({required this.card, required this.deck});
  final FlashCard card;
  final Deck deck;

  int get deckId => deck.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(card.sourceText),
      subtitle: Text(
        card.targetText,
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up_outlined, size: 20),
            tooltip: 'Listen',
            onPressed: () async {
              final ok = await ref
                  .read(ttsServiceProvider)
                  .speak(card.targetText, deck.targetLanguage);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice not available for this language.'),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'edit') {
      context.push('/decks/$deckId/edit-card/${card.id}');
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Remove card?'),
          content: const Text('Remove this card from the deck?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(cardsRepositoryProvider).deleteCard(card.id);
      }
    }
  }
}

// --- Edit Deck Sheet ---

class _EditDeckSheet extends ConsumerStatefulWidget {
  const _EditDeckSheet({required this.deck});
  final Deck deck;

  @override
  ConsumerState<_EditDeckSheet> createState() => _EditDeckSheetState();
}

class _EditDeckSheetState extends ConsumerState<_EditDeckSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.deck.name);
    _descController = TextEditingController(
      text: widget.deck.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    final description = _descController.text.trim();
    await ref
        .read(decksRepositoryProvider)
        .updateDeckDetails(
          id: widget.deck.id,
          name: name,
          description: description.isEmpty ? null : description,
          updatedAt: DateTime.now(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Deck', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Languages',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${languageFlag(widget.deck.sourceLanguage)} '
            '${languageName(widget.deck.sourceLanguage)}'
            '  →  '
            '${languageFlag(widget.deck.targetLanguage)} '
            '${languageName(widget.deck.targetLanguage)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Languages are set when the deck is created and cannot be changed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _nameController.text.trim().isEmpty || _saving
                ? null
                : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
