class AppConstants {
  AppConstants._();

  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String nativeLanguageKey = 'native_language_code';
  static const String targetLanguageKey = 'target_language_code';
  static const String themeModeKey = 'theme_mode';
  static const String maxNewCardsPerDayKey = 'max_new_cards_per_day';
  static const String autoPlayTtsKey = 'study_auto_tts';

  static const int defaultMaxNewCardsPerDay = 10;
  static const double defaultEaseFactor = 2.5;
  static const double minEaseFactor = 1.3;
}
