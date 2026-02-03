import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ExerciseService {
  static String get _host =>
      (dotenv.env['EXERCISE_API_HOST'] ?? 'exercisedb.p.rapidapi.com').trim();

  static List<String> get _keys {
    final candidates = <String>[
      dotenv.env['EXERCISE_API_KEY'] ?? '',
      dotenv.env['EXERCISE_API_KEY_1'] ?? '',
      dotenv.env['EXERCISE_API_KEY_2'] ?? '',
      dotenv.env['EXERCISE_API_KEY_3'] ?? '',
    ];
    return candidates.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
  }

  static final Map<String, Uint8List> _gifCache = {};
  static const Duration _gifDiskTtl = Duration(days: 14);

  static final Map<String, List<Map<String, dynamic>>> _bodyPartCache = {};
  static const Duration _listDiskTtl = Duration(days: 7);

  static Future<http.Response> _getWithFailover(Uri uri) async {
    final keys = _keys;

    if (keys.isEmpty) {
      throw Exception(
        'Exercise API credentials not found. '
        'Set EXERCISE_API_KEY (or EXERCISE_API_KEY_1/2/3) in .env '
        'and ensure dotenv is loaded before calling ExerciseService.',
      );
    }

    Exception? lastError;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];

      try {
        final res = await http.get(
          uri,
          headers: {
            'X-RapidAPI-Key': key,
            'X-RapidAPI-Host': _host,
          },
        );

        if (res.statusCode == 200) return res;

        if (res.statusCode == 401 ||
            res.statusCode == 403 ||
            res.statusCode == 429) {
          lastError = Exception('Key ${i + 1} failed: ${res.statusCode}');
          continue;
        }

        throw Exception('Request failed: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = Exception('Key ${i + 1} error: $e');
      }
    }

    throw lastError ?? Exception('All Exercise API keys failed.');
  }

  static Future<List<String>> fetchTargetList() async {
    final uri = Uri.https(_host, '/exercises/targetList');
    final res = await _getWithFailover(uri);

    final decoded = json.decode(res.body);
    if (decoded is! List) throw Exception('Unexpected response format');

    return decoded.map((e) => e.toString()).toList();
  }

  static String _safeFileName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  static Future<Directory> _listCacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/exercise_lists');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _listFileForBodyPart(String bodyPart) async {
    final dir = await _listCacheDir();
    final part = _safeFileName(bodyPart.toLowerCase());
    return File('${dir.path}/bodypart-$part.json');
  }

  static Future<List<Map<String, dynamic>>?> _readListFromDiskIfFresh(
    String bodyPart,
  ) async {
    try {
      final file = await _listFileForBodyPart(bodyPart);
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
    String bodyPart,
    List<Map<String, dynamic>> list,
  ) async {
    try {
      final file = await _listFileForBodyPart(bodyPart);
      await file.writeAsString(json.encode(list), flush: true);
    } catch (_) {
    }
  }

  static Future<List<Map<String, dynamic>>> fetchExercisesForBodyPart(
    String bodyPart,
  ) async {
    final part = bodyPart.trim();
    if (part.isEmpty) return [];

    final cacheKey = part.toLowerCase();

    final mem = _bodyPartCache[cacheKey];
    if (mem != null && mem.isNotEmpty) {
      return mem;
    }

    final disk = await _readListFromDiskIfFresh(cacheKey);
    if (disk != null && disk.isNotEmpty) {
      _bodyPartCache[cacheKey] = disk;
      return disk;
    }

    final safeBodyPart = Uri.encodeComponent(part);
    final uri = Uri.https(_host, '/exercises/bodyPart/$safeBodyPart');
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
    } catch (_) {
    }
  }

  static Future<Uint8List> fetchExerciseGifBytes({
    required String exerciseId,
    int resolutionPx = 180,
  }) async {
    final id = exerciseId.trim();
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

    final uri = Uri.https(
      _host,
      '/image',
      {'exerciseId': id, 'resolution': resolutionPx.toString()},
    );

    final keys = _keys;
    if (keys.isEmpty) {
      throw Exception(
        'Exercise API credentials not found. '
        'Set EXERCISE_API_KEY (or EXERCISE_API_KEY_1/2/3) in .env.',
      );
    }

    Exception? lastError;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];

      try {
        final res = await http.get(
          uri,
          headers: {
            'X-RapidAPI-Key': key,
            'X-RapidAPI-Host': _host,
            'Accept': 'image/gif',
          },
        );

        if (res.statusCode == 200) {
          final ct = (res.headers['content-type'] ?? '').toLowerCase();
          if (!ct.contains('image/gif')) {
            throw Exception('Expected image/gif but got content-type: $ct');
          }

          final bytes = res.bodyBytes;
          _gifCache[cacheKey] = bytes;
          await _writeGifToDisk(id, resolutionPx, bytes);
          return bytes;
        }

        if (res.statusCode == 401 ||
            res.statusCode == 403 ||
            res.statusCode == 429) {
          lastError = Exception('Key ${i + 1} failed: ${res.statusCode}');
          continue;
        }

        throw Exception('Request failed: ${res.statusCode}');
      } catch (e) {
        lastError = Exception('Key ${i + 1} error: $e');
      }
    }

    throw lastError ?? Exception('All Exercise API keys failed.');
  }

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