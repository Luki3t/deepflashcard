import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/languages.dart';
import 'language_preferences_provider.dart';
import 'onboarding_progress.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key, required this.isNative});

  final bool isNative;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCode = ref.watch(
      isNative ? pendingNativeCodeProvider : pendingTargetCodeProvider,
    );
    final otherCode = ref.watch(
      isNative ? pendingTargetCodeProvider : pendingNativeCodeProvider,
    );

    void onSelect(String code) {
      ref
          .read(
            isNative
                ? pendingNativeCodeProvider.notifier
                : pendingTargetCodeProvider.notifier,
          )
          .set(code);
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OnboardingProgress(currentStep: isNative ? 2 : 3),
                  const SizedBox(height: 24),
                  Text(
                    isNative
                        ? 'What is your native language?'
                        : 'What do you want to learn?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: supportedLanguages.length,
                itemBuilder: (context, i) {
                  final lang = supportedLanguages[i];
                  final isSelected = lang.code == selectedCode;
                  final isDisabled = !isNative && lang.code == otherCode;

                  return ListTile(
                    leading: Text(
                      lang.flag,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(lang.name),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    enabled: !isDisabled,
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: isDisabled ? null : () => onSelect(lang.code),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
              child: FilledButton(
                onPressed: () {
                  if (isNative && selectedCode == otherCode) {
                    // The target still holds the default the user hasn't seen
                    // yet; move it off the native language so the next screen
                    // can't hand back a same-language pair.
                    ref
                        .read(pendingTargetCodeProvider.notifier)
                        .set(firstLanguageOtherThan(selectedCode));
                  }
                  context.push(
                    isNative ? '/onboarding/target' : '/onboarding/confirm',
                  );
                },
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
