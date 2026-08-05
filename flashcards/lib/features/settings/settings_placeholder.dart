import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../core/constants/languages.dart';
import '../../services/translator_service.dart';

class SettingsPlaceholderScreen extends ConsumerWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _LanguagePacksSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('More settings'),
            subtitle: const Text('Coming in Prompt 12'),
          ),
        ],
      ),
    );
  }
}

class _LanguagePacksSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LanguagePacksSection> createState() =>
      _LanguagePacksSectionState();
}

class _LanguagePacksSectionState extends ConsumerState<_LanguagePacksSection> {
  List<TranslateLanguage>? _downloaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final langs = await ref
        .read(translatorServiceProvider)
        .getDownloadedModels();
    if (mounted) setState(() => _downloaded = langs);
  }

  Future<void> _delete(TranslateLanguage lang) async {
    await ref.read(translatorServiceProvider).deleteModel(lang);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Language Packs',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Download translation models'),
          subtitle: const Text('~30 MB per language, used offline'),
          onTap: () =>
              context.push('/onboarding/download').then((_) => _load()),
        ),
        if (_downloaded == null)
          const ListTile(
            leading: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Checking downloads…'),
          )
        else if (_downloaded!.isEmpty)
          ListTile(
            leading: Icon(
              Icons.translate,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            title: const Text('No models downloaded'),
            subtitle: const Text('Tap above to download'),
          )
        else
          ..._downloaded!.map(
            (lang) => ListTile(
              leading: Text(
                languageFlag(lang.bcpCode),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(languageName(lang.bcpCode)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(lang),
                tooltip: 'Delete model',
              ),
            ),
          ),
      ],
    );
  }
}
