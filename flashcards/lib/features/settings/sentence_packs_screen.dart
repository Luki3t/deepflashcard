import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/languages.dart';
import '../../core/utils/network_error.dart';
import '../../data/sentences/sentences_database.dart';
import '../../features/onboarding/language_preferences_provider.dart';
import '../../services/tatoeba_download_service.dart';

class SentencePacksScreen extends ConsumerStatefulWidget {
  const SentencePacksScreen({super.key, this.sourceCode, this.targetCode});

  /// The language pair to list first. Opened from a deck, this is the deck's
  /// pair; left null (Settings), it falls back to the language preferences.
  final String? sourceCode;
  final String? targetCode;

  @override
  ConsumerState<SentencePacksScreen> createState() =>
      _SentencePacksScreenState();
}

class _SentencePacksScreenState extends ConsumerState<SentencePacksScreen> {
  TatoebaManifest? _manifest;
  String? _error;
  bool _loading = true;
  Set<String> _downloaded = {};
  final Map<String, double> _progress = {};
  final Set<String> _downloading = {};
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(tatoebaDownloadServiceProvider);
      final db = ref.read(sentencesDatabaseProvider);
      final manifest = await svc.fetchManifest(forceRefresh: refresh);
      final downloaded = await db.downloadedPairs();
      if (mounted) {
        setState(() {
          _manifest = manifest;
          _downloaded = downloaded.toSet();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyNetworkError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _download(String key) async {
    final parts = key.split('-');
    setState(() {
      _downloading.add(key);
      _progress[key] = 0;
    });
    try {
      await ref
          .read(tatoebaDownloadServiceProvider)
          .downloadPair(
            parts[0],
            parts[1],
            onProgress: (p) {
              if (mounted) setState(() => _progress[key] = p);
            },
          );
      if (mounted) {
        setState(() {
          _downloaded.add(key);
          _downloading.remove(key);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed. ${friendlyNetworkError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _delete(String key) async {
    final parts = key.split('-');
    await ref.read(sentencesDatabaseProvider).deletePair(parts[0], parts[1]);
    if (mounted) setState(() => _downloaded.remove(key));
  }

  Widget _buildList(BuildContext context, WidgetRef ref) {
    final langPrefs = ref.watch(languagePreferencesProvider);
    final nativeCode = widget.sourceCode ?? langPrefs.nativeCode;
    final targetCode = widget.targetCode ?? langPrefs.targetCode;

    final allPairs = _manifest?.pairs.entries.toList() ?? [];

    // Pairs that directly involve the user's native↔target languages
    final relevantKeys = {'$nativeCode-$targetCode', '$targetCode-$nativeCode'};
    final relevantPairs = allPairs
        .where((e) => relevantKeys.contains(e.key))
        .toList();
    final otherPairs = allPairs
        .where((e) => !relevantKeys.contains(e.key))
        .toList();

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Download sentence packs to get example sentences when adding cards. '
            'Each pack is stored on your device and works offline.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(),
        if (relevantPairs.isEmpty && otherPairs.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              'No sentence pack is available for '
              '${languageName(nativeCode)} and ${languageName(targetCode)} yet. '
              'Packs currently pair a language with English.',
            ),
          ),
        if (relevantPairs.isEmpty && otherPairs.isEmpty)
          const ListTile(
            title: Text('No packs available — check your internet connection.'),
          ),
        ...relevantPairs.map((e) => _buildPairTile(context, e.key, e.value)),
        if (relevantPairs.isNotEmpty && otherPairs.isNotEmpty) ...[
          const Divider(),
          InkWell(
            onTap: () => setState(() => _showAll = !_showAll),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _showAll ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showAll
                        ? 'Show fewer packs'
                        : 'Show all ${allPairs.length} language pairs',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showAll)
            ...otherPairs.map((e) => _buildPairTile(context, e.key, e.value)),
        ] else if (relevantPairs.isEmpty)
          ...otherPairs.map((e) => _buildPairTile(context, e.key, e.value)),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Example sentences from Tatoeba.org — CC BY 2.0 FR\n'
            'tatoeba.org contributors',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPairTile(BuildContext context, String key, ManifestPair pair) {
    final isDownloaded = _downloaded.contains(key);
    final isDownloading = _downloading.contains(key);
    final prog = _progress[key] ?? 0.0;

    return ListTile(
      title: Text(_pairLabel(key)),
      subtitle: isDownloading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(value: prog),
                Text(
                  '${(prog * 100).toInt()}% of ${_formatSize(pair.sizeBytes)}',
                ),
              ],
            )
          : Text(
              isDownloaded
                  ? '${pair.sentenceCount} sentences — downloaded'
                  : '${pair.sentenceCount} sentences · ${_formatSize(pair.sizeBytes)}',
            ),
      trailing: isDownloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isDownloaded
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _delete(key),
            )
          : IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download',
              onPressed: () => _download(key),
            ),
    );
  }

  String _pairLabel(String key) {
    final parts = key.split('-');
    final src = parts[0], tgt = parts[1];
    return '${languageFlag(src)} ${languageName(src)}  →  '
        '${languageFlag(tgt)} ${languageName(tgt)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentence Packs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check for updates',
            onPressed: () => _load(refresh: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load sentence packs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _buildList(context, ref),
    );
  }
}
