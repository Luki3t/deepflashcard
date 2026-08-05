import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/languages.dart';
import '../../features/onboarding/language_preferences_provider.dart';
import '../../services/translator_service.dart';

enum _ModelStatus { unknown, notDownloaded, downloading, downloaded }

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  _ModelStatus _sourceStatus = _ModelStatus.unknown;
  _ModelStatus _targetStatus = _ModelStatus.unknown;
  bool _wifiOnly = true;

  late String _sourceCode;
  late String _targetCode;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(languagePreferencesProvider);
    _sourceCode = prefs.nativeCode;
    _targetCode = prefs.targetCode;
    _checkStatuses();
  }

  Future<void> _checkStatuses() async {
    final svc = ref.read(translatorServiceProvider);
    final sl = translateLangFromCode(_sourceCode);
    final tl = translateLangFromCode(_targetCode);
    if (sl == null || tl == null) return;

    final sd = await svc.isModelDownloaded(sl);
    final td = await svc.isModelDownloaded(tl);
    if (mounted) {
      setState(() {
        _sourceStatus = sd
            ? _ModelStatus.downloaded
            : _ModelStatus.notDownloaded;
        _targetStatus = td
            ? _ModelStatus.downloaded
            : _ModelStatus.notDownloaded;
      });
    }
  }

  Future<void> _download() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final svc = ref.read(translatorServiceProvider);
    final sl = translateLangFromCode(_sourceCode);
    final tl = translateLangFromCode(_targetCode);
    if (sl == null || tl == null) return;

    setState(() {
      if (_sourceStatus != _ModelStatus.downloaded) {
        _sourceStatus = _ModelStatus.downloading;
      }
      if (_targetStatus != _ModelStatus.downloaded) {
        _targetStatus = _ModelStatus.downloading;
      }
    });

    await Future.wait([
      if (_sourceStatus == _ModelStatus.downloading)
        svc
            .downloadModel(sl, requireWifi: _wifiOnly)
            .then((_) => _updateStatus(_sourceCode, true))
            .catchError((_) => _updateStatus(_sourceCode, false)),
      if (_targetStatus == _ModelStatus.downloading)
        svc
            .downloadModel(tl, requireWifi: _wifiOnly)
            .then((_) => _updateStatus(_targetCode, true))
            .catchError((_) => _updateStatus(_targetCode, false)),
    ]);
  }

  void _updateStatus(String code, bool success) {
    if (!mounted) return;
    setState(() {
      if (code == _sourceCode) {
        _sourceStatus = success
            ? _ModelStatus.downloaded
            : _ModelStatus.notDownloaded;
      } else {
        _targetStatus = success
            ? _ModelStatus.downloaded
            : _ModelStatus.notDownloaded;
      }
    });
  }

  bool get _bothDownloaded =>
      _sourceStatus == _ModelStatus.downloaded &&
      _targetStatus == _ModelStatus.downloaded;

  bool get _anyDownloading =>
      _sourceStatus == _ModelStatus.downloading ||
      _targetStatus == _ModelStatus.downloading;

  Future<void> _skip() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Skip download?'),
        content: const Text(
          'Without language packs, auto-translation will not work. You can download them later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip anyway'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = Platform.isAndroid || Platform.isIOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Language Packs')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isAvailable ? _buildDownloadUI() : _buildNotAvailableUI(),
      ),
    );
  }

  Widget _buildNotAvailableUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.translate,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Auto-translation is only available on Android and iOS.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can still add cards manually.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: () => context.pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _buildDownloadUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Download translation models (~30 MB each) to enable auto-translation.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _ModelCard(
          name: languageName(_sourceCode),
          flag: languageFlag(_sourceCode),
          status: _sourceStatus,
        ),
        const SizedBox(height: 12),
        _ModelCard(
          name: languageName(_targetCode),
          flag: languageFlag(_targetCode),
          status: _targetStatus,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Download over Wi-Fi only'),
          value: _wifiOnly,
          onChanged: (v) => setState(() => _wifiOnly = v),
          contentPadding: EdgeInsets.zero,
        ),
        const Spacer(),
        if (_bothDownloaded)
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Continue'),
          )
        else
          FilledButton(
            onPressed: _anyDownloading ? null : _download,
            child: _anyDownloading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Download'),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _anyDownloading ? null : _skip,
          child: const Text('Skip'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.name,
    required this.flag,
    required this.status,
  });

  final String name;
  final String flag;
  final _ModelStatus status;

  @override
  Widget build(BuildContext context) {
    final statusWidget = switch (status) {
      _ModelStatus.unknown => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _ModelStatus.notDownloaded => Chip(
        label: const Text('Not downloaded'),
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        side: BorderSide.none,
      ),
      _ModelStatus.downloading => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _ModelStatus.downloaded => Chip(
        label: const Text('Downloaded ✓'),
        labelStyle: const TextStyle(color: Colors.green),
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        side: BorderSide.none,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const Text(
                    '~30 MB',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            statusWidget,
          ],
        ),
      ),
    );
  }
}
