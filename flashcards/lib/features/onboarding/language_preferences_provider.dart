import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/shared_preferences_provider.dart';

// --- Persisted language preferences ---

class LanguagePreferences {
  const LanguagePreferences({
    required this.nativeCode,
    required this.targetCode,
  });
  final String nativeCode;
  final String targetCode;
}

class LanguagePreferencesNotifier extends Notifier<LanguagePreferences> {
  @override
  LanguagePreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return LanguagePreferences(
      nativeCode: prefs.getString(AppConstants.nativeLanguageKey) ?? 'en',
      targetCode: prefs.getString(AppConstants.targetLanguageKey) ?? 'pl',
    );
  }

  Future<void> save(String native, String target) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.nativeLanguageKey, native);
    await prefs.setString(AppConstants.targetLanguageKey, target);
    state = LanguagePreferences(nativeCode: native, targetCode: target);
  }
}

final languagePreferencesProvider =
    NotifierProvider<LanguagePreferencesNotifier, LanguagePreferences>(
      LanguagePreferencesNotifier.new,
    );

// --- Temporary onboarding selection (not yet persisted) ---

class _PendingCodeNotifier extends Notifier<String> {
  _PendingCodeNotifier(this._prefKey, this._fallback);
  final String _prefKey;
  final String _fallback;

  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_prefKey) ?? _fallback;

  void set(String value) => state = value;
}

final pendingNativeCodeProvider =
    NotifierProvider<_PendingCodeNotifier, String>(
      () => _PendingCodeNotifier(AppConstants.nativeLanguageKey, 'en'),
    );

final pendingTargetCodeProvider =
    NotifierProvider<_PendingCodeNotifier, String>(
      () => _PendingCodeNotifier(AppConstants.targetLanguageKey, 'pl'),
    );

// --- Onboarding completion flag ---

class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(sharedPreferencesProvider)
          .getBool(AppConstants.onboardingCompletedKey) ??
      false;

  void set(bool value) => state = value;
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
      OnboardingCompletedNotifier.new,
    );
