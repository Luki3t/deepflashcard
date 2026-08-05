import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/languages.dart';
import '../../data/repositories/decks_repository.dart';
import '../../data/sentences/sentences_database.dart';
import '../../services/translator_service.dart';
import '../../services/tts_service.dart';
import 'card_form_controller.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key, required this.deckId, this.editCardId});

  final int deckId;
  final int? editCardId;

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _notesCtrl;
  bool _initialized = false;

  bool _isTranslating = false;
  bool _isTranslatingReverse = false;
  Timer? _sourceDebounce;
  Timer? _targetDebounce;

  List<ExampleSentence> _examples = [];
  ExampleSentence? _selectedExample;
  bool? _tatoebaPackDownloaded;
  bool? _translationModelsDownloaded;

  bool get isEditMode => widget.editCardId != null;

  @override
  void initState() {
    super.initState();
    _sourceCtrl = TextEditingController();
    _targetCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && isEditMode) {
      _initialized = true;
      _loadCard();
    }
  }

  Future<void> _loadCard() async {
    await ref.read(cardFormProvider.notifier).loadCard(widget.editCardId!);
    final s = ref.read(cardFormProvider);
    _sourceCtrl.text = s.sourceText;
    _targetCtrl.text = s.targetText;
    _notesCtrl.text = s.notes;
    if (s.exampleSentence != null) {
      setState(
        () => _selectedExample = ExampleSentence(
          source: s.exampleSentence!,
          target: s.exampleTranslation ?? '',
        ),
      );
    }
  }

  @override
  void dispose() {
    _sourceDebounce?.cancel();
    _targetDebounce?.cancel();
    _sourceCtrl.dispose();
    _targetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onSourceChanged(String value) {
    ref.read(cardFormProvider.notifier).setSourceText(value);
    if (value.trim().isEmpty) {
      setState(() {
        _examples = [];
        _selectedExample = null;
      });
    }
    _sourceDebounce?.cancel();
    _sourceDebounce = Timer(const Duration(milliseconds: 800), () {
      _autoTranslate(value);
    });
  }

  void _onTargetChanged(String value) {
    ref.read(cardFormProvider.notifier).setTargetText(value);
    _targetDebounce?.cancel();
    _targetDebounce = Timer(const Duration(milliseconds: 800), () {
      _autoTranslateReverse(value);
    });
  }

  Future<void> _checkTatoebaStatus(String sourceLang, String targetLang) async {
    final db = ref.read(sentencesDatabaseProvider);
    final downloaded =
        await db.isPairDownloaded(sourceLang, targetLang) ||
        await db.isPairDownloaded(targetLang, sourceLang);
    if (mounted) setState(() => _tatoebaPackDownloaded = downloaded);
  }

  Future<void> _checkModelStatus(String sourceLang, String targetLang) async {
    final svc = ref.read(translatorServiceProvider);
    final from = translateLangFromCode(sourceLang);
    final to = translateLangFromCode(targetLang);
    if (!svc.isAvailable || from == null || to == null) {
      if (mounted) setState(() => _translationModelsDownloaded = false);
      return;
    }
    final sourceDownloaded = await svc.isModelDownloaded(from);
    final targetDownloaded = await svc.isModelDownloaded(to);
    if (mounted) {
      setState(
        () =>
            _translationModelsDownloaded = sourceDownloaded && targetDownloaded,
      );
    }
  }

  Future<void> _autoTranslate(String text) async {
    if (text.trim().length < 2) return;

    final deck = await ref
        .read(decksRepositoryProvider)
        .getDeckById(widget.deckId);
    if (deck == null || !mounted) return;

    if (_tatoebaPackDownloaded == null) {
      _checkTatoebaStatus(deck.sourceLanguage, deck.targetLanguage);
    }

    final svc = ref.read(translatorServiceProvider);
    if (!svc.isAvailable) {
      _loadExamples(text, deck.sourceLanguage, deck.targetLanguage);
      return;
    }

    // The source field is the only trigger for auto-translate, so the
    // language is already known from the deck — no need to detect it.
    final from = translateLangFromCode(deck.sourceLanguage);
    final to = translateLangFromCode(deck.targetLanguage);
    if (from == null || to == null) {
      _loadExamples(text, deck.sourceLanguage, deck.targetLanguage);
      return;
    }

    if (_translationModelsDownloaded != true) {
      await _checkModelStatus(deck.sourceLanguage, deck.targetLanguage);
    }
    if (_translationModelsDownloaded != true || !mounted) {
      _loadExamples(text, deck.sourceLanguage, deck.targetLanguage);
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final translated = await svc.translate(text, from, to);
      if (mounted && _sourceCtrl.text == text) {
        _targetCtrl.text = translated;
        ref.read(cardFormProvider.notifier).setTargetText(translated);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }

    _loadExamples(text, deck.sourceLanguage, deck.targetLanguage);
  }

  Future<void> _autoTranslateReverse(String text) async {
    if (text.trim().length < 2) return;

    final deck = await ref
        .read(decksRepositoryProvider)
        .getDeckById(widget.deckId);
    if (deck == null || !mounted) return;

    final svc = ref.read(translatorServiceProvider);
    if (!svc.isAvailable) return;

    // The target field is the trigger here, so translate target → source.
    final from = translateLangFromCode(deck.targetLanguage);
    final to = translateLangFromCode(deck.sourceLanguage);
    if (from == null || to == null) return;

    if (_translationModelsDownloaded != true) {
      await _checkModelStatus(deck.sourceLanguage, deck.targetLanguage);
    }
    if (_translationModelsDownloaded != true || !mounted) return;

    setState(() => _isTranslatingReverse = true);
    try {
      final translated = await svc.translate(text, from, to);
      if (mounted && _targetCtrl.text == text) {
        _sourceCtrl.text = translated;
        ref.read(cardFormProvider.notifier).setSourceText(translated);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isTranslatingReverse = false);
    }
  }

  Future<void> _loadExamples(
    String word,
    String sourceLang,
    String targetLang,
  ) async {
    final examples = await ref
        .read(sentencesDatabaseProvider)
        .findExamples(word.trim(), sourceLang, targetLang, limit: 3);
    if (mounted) {
      setState(() {
        _examples = examples;
        if (_selectedExample != null &&
            !examples.any((e) => e.source == _selectedExample!.source)) {
          // Keep selected example even if not in the new results
        }
      });
    }
  }

  void _selectExample(ExampleSentence example) {
    setState(() => _selectedExample = example);
    ref
        .read(cardFormProvider.notifier)
        .setExample(example.source, example.target);
  }

  void _clearExample() {
    setState(() => _selectedExample = null);
    ref.read(cardFormProvider.notifier).setExample(null, null);
  }

  Future<void> _speak(String text, String languageCode) async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(text, languageCode);
  }

  Future<void> _save() async {
    final notifier = ref.read(cardFormProvider.notifier);
    try {
      if (isEditMode) {
        await notifier.update(widget.editCardId!);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Card updated')));
          context.pop();
        }
      } else {
        await notifier.save(widget.deckId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Card added ✓')));
          _sourceCtrl.clear();
          _targetCtrl.clear();
          _notesCtrl.clear();
          setState(() {
            _isTranslating = false;
            _examples = [];
            _selectedExample = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(cardFormProvider);
    final deckFuture = ref.watch(
      Provider.autoDispose(
        (r) => r.watch(decksRepositoryProvider).getDeckById(widget.deckId),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Card' : 'Add Card'),
        actions: [
          TextButton(
            onPressed: formState.isValid && !formState.isSaving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: FutureBuilder(
        future: deckFuture,
        builder: (context, snapshot) {
          final deck = snapshot.data;
          final sourceLang = deck != null
              ? '${languageFlag(deck.sourceLanguage)} ${languageName(deck.sourceLanguage)}'
              : 'Source';
          final targetLang = deck != null
              ? '${languageFlag(deck.targetLanguage)} ${languageName(deck.targetLanguage)}'
              : 'Target';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (deck != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$sourceLang  →  $targetLang',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              TextField(
                controller: _sourceCtrl,
                autofocus: !isEditMode,
                decoration: InputDecoration(
                  labelText: sourceLang,
                  border: const OutlineInputBorder(),
                  suffixIcon: _isTranslatingReverse
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: _onSourceChanged,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetCtrl,
                      decoration: InputDecoration(
                        labelText: targetLang,
                        border: const OutlineInputBorder(),
                        suffixIcon: _isTranslating
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _onTargetChanged,
                    ),
                  ),
                  if (deck != null && _targetCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: IconButton.outlined(
                        icon: const Icon(Icons.volume_up),
                        onPressed: () =>
                            _speak(_targetCtrl.text, deck.targetLanguage),
                        tooltip: 'Listen',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: ref.read(cardFormProvider.notifier).setNotes,
              ),

              // ── Translation model download banner ──────────────────────
              if (deck != null &&
                  _translationModelsDownloaded == false &&
                  (_sourceCtrl.text.trim().isNotEmpty ||
                      _targetCtrl.text.trim().isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Material(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/language-packs').then((_) {
                        _checkModelStatus(
                          deck.sourceLanguage,
                          deck.targetLanguage,
                        );
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.translate,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Download translation models for $sourceLang → $targetLang to auto-translate.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onTertiaryContainer,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onTertiaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Tatoeba download banner ────────────────────────────────
              if (_tatoebaPackDownloaded == false &&
                  _sourceCtrl.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Material(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/sentence-packs'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.download_outlined,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Download example sentence pack for $sourceLang → $targetLang to see examples here.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Example sentences ──────────────────────────────────────
              if (_examples.isNotEmpty || _selectedExample != null) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Example sentences',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (_selectedExample != null) ...[
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearExample,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedExample != null)
                  _ExampleCard(
                    example: _selectedExample!,
                    selected: true,
                    onTap: () {},
                  )
                else
                  ..._examples.map(
                    (e) => _ExampleCard(
                      example: e,
                      selected: false,
                      onTap: () => _selectExample(e),
                    ),
                  ),
              ],

              if (formState.isSaving)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.example,
    required this.selected,
    required this.onTap,
  });

  final ExampleSentence example;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                example.source,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                example.target,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (!selected)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Tap to use',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: scheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
