import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/languages.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/cards_repository.dart';
import '../../data/repositories/decks_repository.dart';
import '../decks/deck_providers.dart';
import '../onboarding/language_preferences_provider.dart';
import 'import_service.dart';

enum _Step { pick, configure, importing, done }

class ImportCsvScreen extends ConsumerStatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  ConsumerState<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends ConsumerState<ImportCsvScreen> {
  _Step _step = _Step.pick;
  String? _fileName;
  CsvParseResult? _parseResult;
  String? _pickError;

  // Deck target selection
  bool _createNewDeck = false;
  int? _selectedDeckId;
  final _newDeckNameCtrl = TextEditingController();
  late String _newDeckSource;
  late String _newDeckTarget;

  int _importedCount = 0;
  int _importTotal = 0;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(languagePreferencesProvider);
    _newDeckSource = prefs.nativeCode;
    _newDeckTarget = prefs.targetCode;
  }

  @override
  void dispose() {
    _newDeckNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _pickError = null);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _pickError = "Couldn't read the selected file.");
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final parsed = const ImportService().parse(content);

    setState(() {
      _fileName = file.name;
      _parseResult = parsed;
      _step = _Step.configure;
    });
  }

  Future<void> _import() async {
    final parsed = _parseResult;
    if (parsed == null || parsed.rows.isEmpty) return;

    int deckId;
    if (_createNewDeck) {
      final name = _newDeckNameCtrl.text.trim();
      if (name.isEmpty) return;
      final now = DateTime.now();
      deckId = await ref
          .read(decksRepositoryProvider)
          .createDeck(
            DecksCompanion.insert(
              name: name,
              sourceLanguage: _newDeckSource,
              targetLanguage: _newDeckTarget,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      if (_selectedDeckId == null) return;
      deckId = _selectedDeckId!;
    }

    setState(() {
      _step = _Step.importing;
      _importedCount = 0;
      _importTotal = parsed.rows.length;
    });

    const batchSize = 100;
    final now = DateTime.now();
    for (var i = 0; i < parsed.rows.length; i += batchSize) {
      final chunk = parsed.rows.skip(i).take(batchSize).map((row) {
        return CardsCompanion.insert(
          deckId: deckId,
          sourceText: row.sourceText,
          targetText: row.targetText,
          notes: row.notes == null ? const Value.absent() : Value(row.notes),
          createdAt: now,
          nextReview: now,
        );
      }).toList();

      await ref.read(cardsRepositoryProvider).insertCardsBatch(chunk);

      if (!mounted) return;
      setState(
        () => _importedCount = (i + chunk.length).clamp(0, _importTotal),
      );
    }

    if (!mounted) return;
    setState(() => _step = _Step.done);
  }

  void _reset() {
    setState(() {
      _step = _Step.pick;
      _fileName = null;
      _parseResult = null;
      _pickError = null;
      _createNewDeck = false;
      _selectedDeckId = null;
      _newDeckNameCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: switch (_step) {
        _Step.pick => _buildPickStep(context),
        _Step.configure => _buildConfigureStep(context),
        _Step.importing => _buildImportingStep(context),
        _Step.done => _buildDoneStep(context),
      },
    );
  }

  Widget _buildPickStep(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a CSV file to import',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Expected format (header required):\n'
              'source_text,target_text,notes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose file'),
            ),
            if (_pickError != null) ...[
              const SizedBox(height: 16),
              Text(
                _pickError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigureStep(BuildContext context) {
    final parsed = _parseResult!;
    final decksAsync = ref.watch(watchAllDecksProvider);
    final previewRows = parsed.rows.take(5).toList();

    final canImport =
        parsed.rows.isNotEmpty &&
        (_createNewDeck
            ? _newDeckNameCtrl.text.trim().isNotEmpty
            : _selectedDeckId != null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_fileName ?? '', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '${parsed.rows.length} valid card(s) found'
          '${parsed.errors.isNotEmpty ? ', ${parsed.errors.length} row(s) skipped' : ''}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (parsed.errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skipped rows',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                ...parsed.errors
                    .take(10)
                    .map(
                      (e) => Text(
                        'Line ${e.line}: ${e.message}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                if (parsed.errors.length > 10)
                  Text(
                    '…and ${parsed.errors.length - 10} more',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (previewRows.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Preview', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: previewRows
                  .map(
                    (r) => ListTile(
                      dense: true,
                      title: Text(r.sourceText),
                      subtitle: Text(r.targetText),
                      trailing: r.notes != null
                          ? const Icon(Icons.note_outlined, size: 18)
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Import into', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Existing deck')),
            ButtonSegment(value: true, label: Text('New deck')),
          ],
          selected: {_createNewDeck},
          onSelectionChanged: (s) => setState(() => _createNewDeck = s.first),
        ),
        const SizedBox(height: 12),
        if (_createNewDeck) ...[
          TextField(
            controller: _newDeckNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Deck name *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LanguageDropdown(
                  label: 'Source',
                  value: _newDeckSource,
                  onChanged: (v) => setState(() => _newDeckSource = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LanguageDropdown(
                  label: 'Target',
                  value: _newDeckTarget,
                  onChanged: (v) => setState(() => _newDeckTarget = v),
                ),
              ),
            ],
          ),
        ] else
          decksAsync.when(
            data: (decks) => decks.isEmpty
                ? const Text('No decks yet — create a new one instead.')
                : DropdownButtonFormField<int>(
                    initialValue: _selectedDeckId,
                    decoration: const InputDecoration(
                      labelText: 'Deck',
                      border: OutlineInputBorder(),
                    ),
                    items: decks
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              d.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDeckId = v),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: canImport ? _import : null,
          child: Text('Import ${parsed.rows.length} card(s)'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _reset,
          child: const Text('Choose a different file'),
        ),
      ],
    );
  }

  Widget _buildImportingStep(BuildContext context) {
    final progress = _importTotal == 0 ? 0.0 : _importedCount / _importTotal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text('Importing $_importedCount / $_importTotal…'),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneStep(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '$_importedCount card(s) imported',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _reset,
              child: const Text('Import another file'),
            ),
          ],
        ),
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
