import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _manifestUrl =
    'https://github.com/Luki3t/deepflashcard/releases/download/tatoeba-v1/manifest.json';
const _cacheKey = 'tatoeba_manifest_json';
const _cacheTimeKey = 'tatoeba_manifest_time';
const _cacheMaxAgeMs = 24 * 3600 * 1000;

class ManifestPair {
  const ManifestPair({
    required this.url,
    required this.sizeBytes,
    required this.sentenceCount,
    required this.checksum,
  });

  final String url;
  final int sizeBytes;
  final int sentenceCount;
  final String checksum;

  factory ManifestPair.fromJson(Map<String, dynamic> j) => ManifestPair(
    url: j['url'] as String,
    sizeBytes: j['size_bytes'] as int,
    sentenceCount: j['sentence_count'] as int,
    checksum: j['checksum_sha256'] as String,
  );
}

class TatoebaManifest {
  const TatoebaManifest({required this.version, required this.pairs});
  final String version;
  final Map<String, ManifestPair> pairs;

  factory TatoebaManifest.fromJson(Map<String, dynamic> j) => TatoebaManifest(
    version: j['version'] as String,
    pairs: (j['pairs'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, ManifestPair.fromJson(v as Map<String, dynamic>)),
    ),
  );
}

class TatoebaDownloadService {
  // Without timeouts an unreachable server leaves the UI spinning for minutes.
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// [forceRefresh] skips the 24 h cache, but a failed refresh still falls
  /// back to the cached manifest rather than leaving the user with nothing.
  Future<TatoebaManifest> fetchManifest({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - cacheTime;

    if (!forceRefresh && cached != null && age < _cacheMaxAgeMs) {
      try {
        return TatoebaManifest.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    final Response<String> response;
    try {
      response = await _dio.get<String>(
        _manifestUrl,
        options: Options(responseType: ResponseType.plain),
      );
    } on DioException {
      // Offline: an outdated manifest is still good enough to list the packs
      // (and to show which ones are already downloaded).
      if (cached != null) {
        try {
          return TatoebaManifest.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        } catch (_) {}
      }
      rethrow;
    }
    final data = response.data!;
    await prefs.setString(_cacheKey, data);
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    return TatoebaManifest.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> downloadPair(
    String source,
    String target, {
    void Function(double progress)? onProgress,
  }) async {
    final manifest = await fetchManifest();
    final key = '$source-$target';
    final pair = manifest.pairs[key];
    if (pair == null) throw Exception('Pair $key not in manifest');

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'sentences'));
    await dir.create(recursive: true);

    final zipPath = p.join(dir.path, 'tatoeba_$key.zip');
    final dbPath = p.join(dir.path, 'tatoeba_$key.db');

    await _dio.download(
      pair.url,
      zipPath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    // Verify checksum
    final file = File(zipPath);
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != pair.checksum) {
      await file.delete();
      throw Exception('Checksum mismatch for $key — download corrupted');
    }

    // Extract db from zip
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      if (entry.isFile && entry.name.endsWith('.db')) {
        final out = File(dbPath);
        await out.writeAsBytes(entry.content as List<int>);
        break;
      }
    }
    await file.delete();
  }

  Future<bool> isPairDownloaded(String source, String target) async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'sentences', 'tatoeba_$source-$target.db');
    return File(dbPath).existsSync();
  }
}

final tatoebaDownloadServiceProvider = Provider<TatoebaDownloadService>(
  (ref) => TatoebaDownloadService(),
);
