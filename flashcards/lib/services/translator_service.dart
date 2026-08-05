import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Maps a 2-letter language code to [TranslateLanguage], or returns null.
TranslateLanguage? translateLangFromCode(String code) {
  try {
    return TranslateLanguage.values.firstWhere((l) => l.bcpCode == code);
  } catch (_) {
    return null;
  }
}

class TranslatorService {
  final _modelManager = OnDeviceTranslatorModelManager();
  final _translators = <String, OnDeviceTranslator>{};

  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  OnDeviceTranslator _translator(TranslateLanguage from, TranslateLanguage to) {
    final key = '${from.bcpCode}_${to.bcpCode}';
    return _translators.putIfAbsent(
      key,
      () => OnDeviceTranslator(sourceLanguage: from, targetLanguage: to),
    );
  }

  Future<bool> isModelDownloaded(TranslateLanguage lang) async {
    if (!isAvailable) return false;
    try {
      return await _modelManager.isModelDownloaded(lang.bcpCode);
    } on PlatformException {
      return false;
    }
  }

  Future<void> downloadModel(
    TranslateLanguage lang, {
    bool requireWifi = true,
  }) async {
    if (!isAvailable) return;
    await _modelManager.downloadModel(
      lang.bcpCode,
      isWifiRequired: requireWifi,
    );
  }

  Future<void> deleteModel(TranslateLanguage lang) async {
    if (!isAvailable) return;
    await _modelManager.deleteModel(lang.bcpCode);
  }

  Future<List<TranslateLanguage>> getDownloadedModels() async {
    if (!isAvailable) return [];
    try {
      // Iterate known supported languages and check each
      final results = <TranslateLanguage>[];
      for (final lang in TranslateLanguage.values) {
        if (await isModelDownloaded(lang)) results.add(lang);
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Translates [text] from [from] to [to].
  Future<String> translate(
    String text,
    TranslateLanguage from,
    TranslateLanguage to,
  ) async {
    return _translator(from, to).translateText(text);
  }

  void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}

final translatorServiceProvider = Provider<TranslatorService>((ref) {
  final s = TranslatorService();
  ref.onDispose(s.dispose);
  return s;
});
