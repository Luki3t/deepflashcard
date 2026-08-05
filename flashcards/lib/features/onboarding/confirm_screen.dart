import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/languages.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/decks_repository.dart';
import 'language_preferences_provider.dart';
import 'onboarding_progress.dart';

class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key});

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  bool _loading = false;

  Future<void> _start() async {
    if (_loading) return;
    setState(() => _loading = true);

    final nativeCode = ref.read(pendingNativeCodeProvider);
    final targetCode = ref.read(pendingTargetCodeProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    final now = DateTime.now();
    await ref
        .read(decksRepositoryProvider)
        .createDeck(
          DecksCompanion.insert(
            name: 'My First Deck',
            sourceLanguage: nativeCode,
            targetLanguage: targetCode,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await ref
        .read(languagePreferencesProvider.notifier)
        .save(nativeCode, targetCode);
    await prefs.setBool(AppConstants.onboardingCompletedKey, true);
    ref.read(onboardingCompletedProvider.notifier).set(true);

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final nativeCode = ref.watch(pendingNativeCodeProvider);
    final targetCode = ref.watch(pendingTargetCodeProvider);
    final native = languageByCode(nativeCode);
    final target = languageByCode(targetCode);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingProgress(currentStep: 4),
              const Spacer(),
              Text(
                'Ready to learn!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _LanguageCard(
                label: 'I speak',
                flag: native.flag,
                name: native.name,
              ),
              const SizedBox(height: 4),
              Center(
                child: Icon(
                  Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              _LanguageCard(
                label: 'I want to learn',
                flag: target.flag,
                name: target.name,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _start,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start Learning'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.flag,
    required this.name,
  });

  final String label;
  final String flag;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(name, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
