import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'package:flashcards/services/translator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('translateLangFromCode', () {
    test('resolves known BCP-47 codes to their TranslateLanguage', () {
      expect(translateLangFromCode('en'), TranslateLanguage.english);
      expect(translateLangFromCode('pl'), TranslateLanguage.polish);
      expect(translateLangFromCode('de'), TranslateLanguage.german);
    });

    test('returns null for an unknown code', () {
      expect(translateLangFromCode('xx'), isNull);
    });

    test('returns null for empty string', () {
      expect(translateLangFromCode(''), isNull);
    });

    test('is case-sensitive (no normalization)', () {
      expect(translateLangFromCode('EN'), isNull);
    });
  });

  group('TranslatorService.isAvailable', () {
    test('is false on the (non-mobile) test host platform', () {
      expect(TranslatorService().isAvailable, isFalse);
    });
  });

  group('TranslatorService guarded methods on an unavailable platform', () {
    // Assert the platform channel is never touched by wiring a handler
    // that fails the test if invoked.
    const channel = MethodChannel('google_mlkit_on_device_translator');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        fail('channel method "${call.method}" should not be invoked when unavailable');
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('isModelDownloaded short-circuits to false', () async {
      final result = await TranslatorService().isModelDownloaded(
        TranslateLanguage.english,
      );
      expect(result, isFalse);
    });

    test('downloadModel is a no-op', () async {
      await TranslatorService().downloadModel(TranslateLanguage.english);
    });

    test('deleteModel is a no-op', () async {
      await TranslatorService().deleteModel(TranslateLanguage.english);
    });

    test('getDownloadedModels short-circuits to an empty list', () async {
      final result = await TranslatorService().getDownloadedModels();
      expect(result, isEmpty);
    });
  });

  group('TranslatorService.translate', () {
    const channel = MethodChannel('google_mlkit_on_device_translator');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'nlp#startLanguageTranslator':
            return 'translated text';
          case 'nlp#closeLanguageTranslator':
            return null;
          default:
            fail('unexpected method call "${call.method}"');
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends source/target/text over the platform channel and returns the result', () async {
      final service = TranslatorService();

      final result = await service.translate(
        'hello',
        TranslateLanguage.english,
        TranslateLanguage.polish,
      );

      expect(result, 'translated text');
      expect(calls, hasLength(1));
      expect(calls.single.method, 'nlp#startLanguageTranslator');
      expect(calls.single.arguments['text'], 'hello');
      expect(calls.single.arguments['source'], 'en');
      expect(calls.single.arguments['target'], 'pl');
    });

    test('reuses the same underlying translator for a repeated language pair', () async {
      final service = TranslatorService();

      await service.translate('a', TranslateLanguage.english, TranslateLanguage.polish);
      await service.translate('b', TranslateLanguage.english, TranslateLanguage.polish);

      expect(calls, hasLength(2));
      expect(calls[0].arguments['id'], calls[1].arguments['id']);
    });

    test('uses a distinct translator for a different language pair', () async {
      final service = TranslatorService();

      await service.translate('a', TranslateLanguage.english, TranslateLanguage.polish);
      await service.translate('a', TranslateLanguage.english, TranslateLanguage.german);

      expect(calls, hasLength(2));
      expect(calls[0].arguments['id'], isNot(calls[1].arguments['id']));
    });

    test('dispose closes every cached translator', () async {
      final service = TranslatorService();

      await service.translate('a', TranslateLanguage.english, TranslateLanguage.polish);
      await service.translate('a', TranslateLanguage.english, TranslateLanguage.german);
      calls.clear();

      service.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(calls, hasLength(2));
      expect(calls.every((c) => c.method == 'nlp#closeLanguageTranslator'), isTrue);
    });
  });
}
