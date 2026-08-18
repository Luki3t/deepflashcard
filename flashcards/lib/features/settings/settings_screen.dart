import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/languages.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../features/onboarding/language_preferences_provider.dart';
import '../../services/notification_service.dart';
import '../../services/translator_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _NotificationsSection(),
          Divider(height: 1),
          _AppearanceSection(),
          Divider(height: 1),
          _LanguagesSection(),
          Divider(height: 1),
          _StudySection(),
          Divider(height: 1),
          _LanguagePacksSection(),
          Divider(height: 1),
          _SentencePacksSection(),
          Divider(height: 1),
          _DataSection(),
          Divider(height: 1),
          _AboutSection(),
        ],
      ),
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ─── Notifications ──────────────────────────────────────────────────────────

class _NotificationsSection extends ConsumerStatefulWidget {
  const _NotificationsSection();

  @override
  ConsumerState<_NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<_NotificationsSection> {
  static const _enabledKey = 'notifications_enabled';
  static const _hourKey = 'notification_hour';
  static const _minuteKey = 'notification_minute';
  static const _messageKey = 'notification_message';

  bool get _enabled =>
      ref.read(sharedPreferencesProvider).getBool(_enabledKey) ?? false;
  int get _hour => ref.read(sharedPreferencesProvider).getInt(_hourKey) ?? 19;
  int get _minute =>
      ref.read(sharedPreferencesProvider).getInt(_minuteKey) ?? 0;
  String get _message =>
      ref.read(sharedPreferencesProvider).getString(_messageKey) ??
      'Time to review your flashcards!';

  late final TextEditingController _msgCtrl;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController(text: _message);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_enabledKey, value);
    final svc = ref.read(notificationServiceProvider);
    if (value) {
      await svc.requestPermissions();
      await svc.scheduleDailyReminder(
        time: TimeOfDay(hour: _hour, minute: _minute),
        message: _message,
      );
    } else {
      await svc.cancelAll();
    }
    setState(() {});
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_hourKey, picked.hour);
    await prefs.setInt(_minuteKey, picked.minute);
    if (_enabled) {
      await ref
          .read(notificationServiceProvider)
          .scheduleDailyReminder(time: picked, message: _message);
    }
    setState(() {});
  }

  Future<void> _saveMessage(String msg) async {
    await ref.read(sharedPreferencesProvider).setString(_messageKey, msg);
    if (_enabled) {
      await ref
          .read(notificationServiceProvider)
          .scheduleDailyReminder(
            time: TimeOfDay(hour: _hour, minute: _minute),
            message: msg,
          );
    }
  }

  String _formatTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final notAvailable = !Platform.isAndroid && !Platform.isIOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Notifications'),
        if (notAvailable)
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Notifications only available on Android / iOS'),
          )
        else ...[
          SwitchListTile(
            title: const Text('Daily reminder'),
            value: _enabled,
            onChanged: _setEnabled,
          ),
          ListTile(
            title: const Text('Reminder time'),
            subtitle: Text(_formatTime(_hour, _minute)),
            trailing: const Icon(Icons.access_time),
            enabled: _enabled,
            onTap: _enabled ? _pickTime : null,
          ),
          ListTile(
            title: const Text('Message'),
            subtitle: TextField(
              controller: _msgCtrl,
              enabled: _enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _saveMessage,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Appearance ─────────────────────────────────────────────────────────────

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Appearance'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ),
      ],
    );
  }
}

// ─── Languages ──────────────────────────────────────────────────────────────

class _LanguagesSection extends ConsumerWidget {
  const _LanguagesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(languagePreferencesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Languages'),
        ListTile(
          title: const Text('Native language (I speak)'),
          subtitle: const Text('Default source for new decks'),
          trailing: _LangDropdown(
            value: prefs.nativeCode,
            onChanged: (code) => ref
                .read(languagePreferencesProvider.notifier)
                .save(code, prefs.targetCode),
          ),
        ),
        ListTile(
          title: const Text('Learning language (I want to learn)'),
          subtitle: const Text('Default target for new decks'),
          trailing: _LangDropdown(
            value: prefs.targetCode,
            onChanged: (code) => ref
                .read(languagePreferencesProvider.notifier)
                .save(prefs.nativeCode, code),
          ),
        ),
      ],
    );
  }
}

class _LangDropdown extends StatelessWidget {
  const _LangDropdown({required this.value, required this.onChanged});
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox.shrink(),
      items: supportedLanguages
          .map(
            (l) => DropdownMenuItem(
              value: l.code,
              child: Text('${l.flag} ${l.name}'),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ─── Study ───────────────────────────────────────────────────────────────────

class _StudySection extends ConsumerStatefulWidget {
  const _StudySection();

  @override
  ConsumerState<_StudySection> createState() => _StudySectionState();
}

class _StudySectionState extends ConsumerState<_StudySection> {
  late final TextEditingController _newCardsCtrl;
  late final TextEditingController _reviewsCtrl;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final currentNew =
        prefs.getInt(AppConstants.maxNewCardsPerDayKey) ??
        AppConstants.defaultMaxNewCardsPerDay;
    final currentReviews =
        prefs.getInt(AppConstants.maxReviewsPerDayKey) ??
        AppConstants.defaultMaxReviewsPerDay;
    _newCardsCtrl = TextEditingController(text: '$currentNew');
    _reviewsCtrl = TextEditingController(text: '$currentReviews');
  }

  @override
  void dispose() {
    _newCardsCtrl.dispose();
    _reviewsCtrl.dispose();
    super.dispose();
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.read(sharedPreferencesProvider);
    final autoTts = prefs.getBool(AppConstants.autoPlayTtsKey) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Study'),
        SwitchListTile(
          title: const Text('Auto-play voice on flip'),
          subtitle: const Text('Speaks the translation when you flip a card'),
          value: autoTts,
          onChanged: (v) {
            prefs.setBool(AppConstants.autoPlayTtsKey, v);
            setState(() {});
          },
        ),
        ListTile(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Max new cards per day'),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showInfoDialog(
                  'Max new cards per day',
                  "Caps how many cards you've never studied before get "
                      'introduced each day. Cards you have already studied '
                      "and are due for review don't count against this "
                      'limit — see "Max reviews per day" for those.',
                ),
              ),
            ],
          ),
          trailing: SizedBox(
            width: 64,
            child: TextField(
              controller: _newCardsCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) {
                  ref
                      .read(sharedPreferencesProvider)
                      .setInt(AppConstants.maxNewCardsPerDayKey, n);
                }
              },
            ),
          ),
        ),
        ListTile(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Max reviews per day'),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showInfoDialog(
                  'Max reviews per day',
                  'Caps how many due cards — cards you have already '
                      'studied before and that came back up for review — '
                      "you study each day. Brand-new cards don't count "
                      'against this limit — see "Max new cards per day" '
                      'for those.',
                ),
              ),
            ],
          ),
          trailing: SizedBox(
            width: 64,
            child: TextField(
              controller: _reviewsCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) {
                  ref
                      .read(sharedPreferencesProvider)
                      .setInt(AppConstants.maxReviewsPerDayKey, n);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Language packs (ML Kit) ─────────────────────────────────────────────────

class _LanguagePacksSection extends ConsumerStatefulWidget {
  const _LanguagePacksSection();

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Language Packs (Translation)'),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Download translation models'),
          subtitle: const Text('~30 MB per language, used offline'),
          onTap: () => context.push('/language-packs').then((_) => _load()),
        ),
        if (_downloaded == null)
          const ListTile(
            leading: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Checking…'),
          )
        else if (_downloaded!.isEmpty)
          ListTile(
            leading: Icon(
              Icons.translate,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            title: const Text('No models downloaded'),
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
                tooltip: 'Delete model',
                onPressed: () async {
                  await ref.read(translatorServiceProvider).deleteModel(lang);
                  await _load();
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Sentence packs (Tatoeba) ────────────────────────────────────────────────

class _SentencePacksSection extends StatelessWidget {
  const _SentencePacksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Sentence Packs (Tatoeba)'),
        ListTile(
          leading: const Icon(Icons.format_quote_outlined),
          title: const Text('Example sentence packs'),
          subtitle: const Text('Download offline sentence databases'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/sentence-packs'),
        ),
      ],
    );
  }
}

// ─── Data (CSV) ─────────────────────────────────────────────────────────────

class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Data'),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('Import CSV'),
          subtitle: const Text('source_text, target_text, notes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/import-csv'),
        ),
      ],
    );
  }
}

// ─── About ──────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('About'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About DeepFlashcard'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/about'),
        ),
      ],
    );
  }
}
