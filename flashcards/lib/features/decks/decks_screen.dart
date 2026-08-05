import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/languages.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/decks_repository.dart';
import '../onboarding/language_preferences_provider.dart';
import '../stats/stats_providers.dart';
import 'deck_providers.dart';

class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(watchAllDecksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Decks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: decksAsync.when(
        data: (decks) => Column(
          children: [
            _TodayBanner(),
            Expanded(
              child: decks.isEmpty
                  ? _EmptyState(
                      onCreateDeck: () => _showCreateDeckDialog(context, ref),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: decks.length,
                      itemBuilder: (context, i) => _DeckCard(deck: decks[i]),
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDeckDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Deck'),
      ),
    );
  }

  Future<void> _showCreateDeckDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreateDeckSheet(),
    );
  }
}

class _DeckCard extends ConsumerWidget {
  const _DeckCard({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(watchCardsForDeckProvider(deck.id));
    final cards = cardsAsync.value ?? [];
    final now = DateTime.now();
    final dueCount = cards.where((c) => !c.nextReview.isAfter(now)).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/decks/${deck.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${languageFlag(deck.sourceLanguage)} ${languageName(deck.sourceLanguage)}'
                      '  →  '
                      '${languageFlag(deck.targetLanguage)} ${languageName(deck.targetLanguage)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cards.length} cards',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (dueCount > 0)
                Badge(
                  label: Text('$dueCount'),
                  child: const Icon(Icons.school_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateDeck});
  final VoidCallback onCreateDeck;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.style_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text('No decks yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create your first deck to start learning.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateDeck,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Deck'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateDeckSheet extends ConsumerStatefulWidget {
  const _CreateDeckSheet();

  @override
  ConsumerState<_CreateDeckSheet> createState() => _CreateDeckSheetState();
}

class _CreateDeckSheetState extends ConsumerState<_CreateDeckSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  late String _sourceCode;
  late String _targetCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(languagePreferencesProvider);
    _sourceCode = prefs.nativeCode;
    _targetCode = prefs.targetCode;
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

    final now = DateTime.now();
    await ref
        .read(decksRepositoryProvider)
        .createDeck(
          DecksCompanion.insert(
            name: name,
            description: _descController.text.trim().isEmpty
                ? const Value(null)
                : Value(_descController.text.trim()),
            sourceLanguage: _sourceCode,
            targetLanguage: _targetCode,
            createdAt: now,
            updatedAt: now,
          ),
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
          Text('New Deck', style: Theme.of(context).textTheme.titleLarge),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LanguageDropdown(
                  label: 'Native (I speak)',
                  value: _sourceCode,
                  onChanged: (v) => setState(() => _sourceCode = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LanguageDropdown(
                  label: 'Learning',
                  value: _targetCode,
                  onChanged: (v) => setState(() => _targetCode = v),
                ),
              ),
            ],
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
                : const Text('Create Deck'),
          ),
        ],
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: supportedLanguages
          .map(
            (l) => DropdownMenuItem(
              value: l.code,
              child: Text(
                '${l.flag} ${l.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _TodayBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(todayProgressProvider);
    return progressAsync.when(
      data: (p) {
        if (p.due == 0) return const SizedBox.shrink();
        final ratio = p.due == 0 ? 1.0 : p.reviewed / p.due;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.today_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Today: ${p.reviewed} / ${p.due} reviewed',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
