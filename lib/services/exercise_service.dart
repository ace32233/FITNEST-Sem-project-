import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// ExerciseService
/// - Uses RapidAPI (exercisedb.p.rapidapi.com by default)
/// - Key failover (rotates keys on 401/403/429)
/// - Caches exercise lists (memory + disk)
/// - Caches GIF bytes (memory + disk)
/// - ✅ GIFs WORK reliably via RapidAPI /image?exerciseId=...&resolution=180
///   (this matches your OLD exercise page code that only passes exerciseId)
class ExerciseService {
  // ------------------ Config ------------------
  static String get _host =>
      (dotenv.env['EXERCISE_API_HOST'] ?? 'exercisedb.p.rapidapi.com').trim();

  static List<String> get _keys {
    final candidates = <String>[
      dotenv.env['EXERCISE_API_KEY_1'] ?? '',
      dotenv.env['EXERCISE_API_KEY_2'] ?? '',
    ];
    return candidates.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
  }

  // ------------------ In-memory caches ------------------
  static final Map<String, Uint8List> _gifCache = {};
  static final Map<String, List<Map<String, dynamic>>> _bodyPartCache = {};

  // ------------------ Disk cache TTLs ------------------
  static const Duration _gifDiskTtl = Duration(days: 14);
  static const Duration _listDiskTtl = Duration(days: 7);

  // ------------------ Helpers ------------------
  static String _safeFileName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  /// RapidAPI GET with key failover.
  /// Rotates keys only on 401/403/429.
  static Future<http.Response> _getWithFailover(Uri uri,
      {Map<String, String>? extraHeaders}) async {
    final keys = _keys;

    if (keys.isEmpty) {
      throw Exception(
        'Exercise API credentials not found. '
        'Set EXERCISE_API_KEY_1 and/or EXERCISE_API_KEY_2 in .env '
        'and ensure dotenv is loaded before calling ExerciseService.',
      );
    }

    Exception? lastError;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];

      try {
        final headers = <String, String>{
          'X-RapidAPI-Key': key,
          'X-RapidAPI-Host': _host,
          if (extraHeaders != null) ...extraHeaders,
        };

        final res = await http.get(uri, headers: headers);

        if (res.statusCode == 200) return res;

        if (res.statusCode == 401 ||
            res.statusCode == 403 ||
            res.statusCode == 429) {
          lastError = Exception('Key ${i + 1} failed: ${res.statusCode}');
          continue;
        }

        // Other errors: don't rotate keys
        throw Exception('Request failed: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = Exception('Key ${i + 1} error: $e');
      }
    }

    throw lastError ?? Exception('All Exercise API keys failed.');
  }

  // =========================================================
  // LISTS / LOOKUPS
  // =========================================================

  static Future<List<String>> fetchTargetList() async {
    final uri = Uri.https(_host, '/exercises/targetList');
    final res = await _getWithFailover(uri);

    final decoded = json.decode(res.body);
    if (decoded is! List) throw Exception('Unexpected response format');

    return decoded.map((e) => e.toString()).toList();
  }

  static Future<List<String>> fetchBodyPartList() async {
    final uri = Uri.https(_host, '/exercises/bodyPartList');
    final res = await _getWithFailover(uri);

    final decoded = json.decode(res.body);
    if (decoded is! List) throw Exception('Unexpected response format');

    return decoded.map((e) => e.toString()).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchExercisesByTarget(
    String target,
  ) async {
    final normalized = Uri.decodeComponent(target).trim();
    if (normalized.isEmpty) return [];

    // Use pathSegments to avoid double-encoding
    final uri = Uri(
      scheme: 'https',
      host: _host,
      pathSegments: ['exercises', 'target', normalized],
    );

    final res = await _getWithFailover(uri);

    final decoded = json.decode(res.body);
    if (decoded is! List) throw Exception('Unexpected response format');

    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // =========================================================
  // EXERCISES BY BODY PART (WITH DISK CACHE)
  // =========================================================

  static Future<Directory> _listCacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/exercise_lists');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _listFileForBodyPart(String cacheKey) async {
    final dir = await _listCacheDir();
    final safe = _safeFileName(cacheKey.toLowerCase());
    return File('${dir.path}/bodypart-$safe.json');
  }

  static Future<List<Map<String, dynamic>>?> _readListFromDiskIfFresh(
    String cacheKey,
  ) async {
    try {
      final file = await _listFileForBodyPart(cacheKey);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);

      if (age > _listDiskTtl) {
        await file.delete().catchError((_) {});
        return null;
      }

      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;

      final decoded = json.decode(text);
      if (decoded is! List) return null;

      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeListToDisk(
    String cacheKey,
    List<Map<String, dynamic>> list,
  ) async {
    try {
      final file = await _listFileForBodyPart(cacheKey);
      await file.writeAsString(json.encode(list), flush: true);
    } catch (_) {}
  }

  /// ✅ Avoids double-encoding for values with spaces like "upper legs".
  static Future<List<Map<String, dynamic>>> fetchExercisesForBodyPart(
    String bodyPart,
  ) async {
    final normalized = Uri.decodeComponent(bodyPart).trim();
    if (normalized.isEmpty) return [];

    final cacheKey = normalized.toLowerCase();

    // Memory cache
    final mem = _bodyPartCache[cacheKey];
    if (mem != null && mem.isNotEmpty) return mem;

    // Disk cache
    final disk = await _readListFromDiskIfFresh(cacheKey);
    if (disk != null && disk.isNotEmpty) {
      _bodyPartCache[cacheKey] = disk;
      return disk;
    }

    // IMPORTANT: pathSegments encodes exactly once
    final uri = Uri(
      scheme: 'https',
      host: _host,
      pathSegments: ['exercises', 'bodyPart', normalized],
    );

    final res = await _getWithFailover(uri);

    final decoded = json.decode(res.body);
    if (decoded is! List) throw Exception('Unexpected response format');

    final list = decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    _bodyPartCache[cacheKey] = list;
    await _writeListToDisk(cacheKey, list);

    return list;
  }

  // =========================================================
  // GIF CACHE (DISK) HELPERS
  // =========================================================

  static Future<Directory> _gifCacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/exercise_gifs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _gifFileFor(String exerciseId, int resolutionPx) async {
    final dir = await _gifCacheDir();
    final id = _safeFileName(exerciseId);
    return File('${dir.path}/$id-$resolutionPx.gif');
  }

  static Future<Uint8List?> _readGifFromDiskIfFresh(
    String exerciseId,
    int resolutionPx,
  ) async {
    try {
      final file = await _gifFileFor(exerciseId, resolutionPx);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);

      if (age > _gifDiskTtl) {
        await file.delete().catchError((_) {});
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeGifToDisk(
    String exerciseId,
    int resolutionPx,
    Uint8List bytes,
  ) async {
    try {
      final file = await _gifFileFor(exerciseId, resolutionPx);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  // =========================================================
  // GIF FETCH (✅ WORKING OLD WAY)
  // =========================================================

  /// ✅ This is the method your OLD exercise page uses.
  /// It fetches GIF bytes using RapidAPI /image endpoint.
  ///
  /// Call:
  /// ExerciseService.fetchExerciseGifBytes(exerciseId: '0001', resolutionPx: 180)
  static Future<Uint8List> fetchExerciseGifBytes({
    required String exerciseId,
    int resolutionPx = 180,
  }) async {
    final id = exerciseId.trim();
    if (id.isEmpty) throw Exception('exerciseId is empty');

    // Your app expects 180; keep it stable
    if (resolutionPx != 180) resolutionPx = 180;

    final cacheKey = '$id-$resolutionPx';

    // Memory cache
    final mem = _gifCache[cacheKey];
    if (mem != null && mem.isNotEmpty) return mem;

    // Disk cache
    final disk = await _readGifFromDiskIfFresh(id, resolutionPx);
    if (disk != null && disk.isNotEmpty) {
      _gifCache[cacheKey] = disk;
      return disk;
    }

    // RapidAPI image endpoint
    final uri = Uri.https(
      _host,
      '/image',
      {'exerciseId': id, 'resolution': resolutionPx.toString()},
    );

    // Must accept gif
    final res = await _getWithFailover(uri, extraHeaders: {
      'Accept': 'image/gif',
    });

    final bytes = res.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception('Empty GIF bytes returned');
    }

    _gifCache[cacheKey] = bytes;
    await _writeGifToDisk(id, resolutionPx, bytes);

    return bytes;
  }

  // =========================================================
  // OPTIONAL: If later you want gifUrl-based fetching
  // =========================================================

  /// Optional helper: try gifUrl directly first, fallback to /image.
  /// Not required by your old UI, but safe if you decide to pass gifUrl later.
  static Future<Uint8List> fetchExerciseGifBytesHybrid({
    required String exerciseId,
    required String gifUrl,
    int resolutionPx = 180,
  }) async {
    final id = exerciseId.trim();
    final url = gifUrl.trim();
    if (id.isEmpty) throw Exception('exerciseId is empty');

    if (resolutionPx != 180) resolutionPx = 180;

    final cacheKey = '$id-$resolutionPx';

    final mem = _gifCache[cacheKey];
    if (mem != null && mem.isNotEmpty) return mem;

    final disk = await _readGifFromDiskIfFresh(id, resolutionPx);
    if (disk != null && disk.isNotEmpty) {
      _gifCache[cacheKey] = disk;
      return disk;
    }

    // Try direct gifUrl (NO RapidAPI headers unless it's rapidapi host)
    if (url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        http.Response res;

        if (uri.host == _host) {
          res = await _getWithFailover(uri);
        } else {
          res = await http.get(uri);
        }

        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final bytes = res.bodyBytes;
          _gifCache[cacheKey] = bytes;
          await _writeGifToDisk(id, resolutionPx, bytes);
          return bytes;
        }
      } catch (_) {
        // ignore and fallback
      }
    }

    // Fallback to the reliable endpoint
    return fetchExerciseGifBytes(exerciseId: id, resolutionPx: resolutionPx);
  }

  // =========================================================
  // CACHE CLEAR HELPERS
  // =========================================================

  static void clearGifMemoryCache() {
    _gifCache.clear();
  }

  static Future<void> clearGifDiskCache() async {
    _gifCache.clear();
    try {
      final dir = await _gifCacheDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  static void clearExerciseListMemoryCache() {
    _bodyPartCache.clear();
  }

  static Future<void> clearExerciseListDiskCache() async {
    _bodyPartCache.clear();
    try {
      final dir = await _listCacheDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  static Future<void> clearAllExerciseCaches() async {
    clearGifMemoryCache();
    clearExerciseListMemoryCache();
    await clearGifDiskCache();
    await clearExerciseListDiskCache();
  }
}