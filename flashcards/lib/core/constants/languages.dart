class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.flag,
  });
  final String code;
  final String name;
  final String flag;
}

const supportedLanguages = <AppLanguage>[
  AppLanguage(code: 'en', name: 'English', flag: '🇬🇧'),
  AppLanguage(code: 'pl', name: 'Polish', flag: '🇵🇱'),
  AppLanguage(code: 'de', name: 'German', flag: '🇩🇪'),
  AppLanguage(code: 'es', name: 'Spanish', flag: '🇪🇸'),
  AppLanguage(code: 'fr', name: 'French', flag: '🇫🇷'),
  AppLanguage(code: 'it', name: 'Italian', flag: '🇮🇹'),
  AppLanguage(code: 'pt', name: 'Portuguese', flag: '🇵🇹'),
  AppLanguage(code: 'ru', name: 'Russian', flag: '🇷🇺'),
  AppLanguage(code: 'uk', name: 'Ukrainian', flag: '🇺🇦'),
  AppLanguage(code: 'zh', name: 'Chinese', flag: '🇨🇳'),
  AppLanguage(code: 'ja', name: 'Japanese', flag: '🇯🇵'),
  AppLanguage(code: 'ko', name: 'Korean', flag: '🇰🇷'),
  AppLanguage(code: 'nl', name: 'Dutch', flag: '🇳🇱'),
  AppLanguage(code: 'sv', name: 'Swedish', flag: '🇸🇪'),
  AppLanguage(code: 'no', name: 'Norwegian', flag: '🇳🇴'),
  AppLanguage(code: 'cs', name: 'Czech', flag: '🇨🇿'),
  AppLanguage(code: 'sk', name: 'Slovak', flag: '🇸🇰'),
  AppLanguage(code: 'hu', name: 'Hungarian', flag: '🇭🇺'),
  AppLanguage(code: 'tr', name: 'Turkish', flag: '🇹🇷'),
];

AppLanguage languageByCode(String code) => supportedLanguages.firstWhere(
  (l) => l.code == code,
  orElse: () => const AppLanguage(code: '??', name: 'Unknown', flag: '🏳'),
);

String languageName(String code) => languageByCode(code).name;
String languageFlag(String code) => languageByCode(code).flag;
