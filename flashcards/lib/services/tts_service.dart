import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Maps 2-letter language codes to locale strings accepted by flutter_tts.
String _toLocale(String code) => switch (code) {
  'en' => 'en-US',
  'pl' => 'pl-PL',
  'de' => 'de-DE',
  'fr' => 'fr-FR',
  'es' => 'es-ES',
  'it' => 'it-IT',
  'pt' => 'pt-PT',
  'ru' => 'ru-RU',
  'uk' => 'uk-UA',
  'zh' => 'zh-CN',
  'ja' => 'ja-JP',
  'ko' => 'ko-KR',
  'nl' => 'nl-NL',
  'sv' => 'sv-SE',
  'no' => 'nb-NO',
  'cs' => 'cs-CZ',
  'sk' => 'sk-SK',
  'hu' => 'hu-HU',
  'tr' => 'tr-TR',
  _ => code,
};

class TtsService {
  TtsService() {
    _init();
  }

  final _tts = FlutterTts();

  Future<void> _init() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  /// Returns false if the language voice is not installed on the device.
  Future<bool> isLanguageAvailable(String code) async {
    try {
      final result = await _tts.isLanguageAvailable(_toLocale(code));
      return result == true || result == 1;
    } catch (_) {
      return false;
    }
  }

  /// Speaks [text] in [code] language.
  /// Always returns true — errors are silent (TTS is best-effort; outcome is audible).
  Future<bool> speak(String text, String code) async {
    try {
      try {
        await _tts.setLanguage(_toLocale(code));
      } catch (_) {}
      await _tts.speak(text);
    } catch (_) {}
    return true;
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    _tts.stop();
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final s = TtsService();
  ref.onDispose(s.dispose);
  return s;
});
