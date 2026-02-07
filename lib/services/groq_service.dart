import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Matches what your NutritionPage expects.
class NutritionData {
  final String foodName;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionData({
    required this.foodName,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
        'foodName': foodName,
        'servingSize': servingSize,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  static NutritionData fromJson(Map<String, dynamic> raw) {
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().trim()) ?? 0.0;
    }

    String toS(dynamic v, String fallback) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? fallback : s;
    }

    return NutritionData(
      foodName: toS(raw['foodName'], 'Food'),
      servingSize: toS(raw['servingSize'], '1 serving'),
      calories: toD(raw['calories']).clamp(0, double.infinity),
      protein: toD(raw['protein']).clamp(0, double.infinity),
      carbs: toD(raw['carbs']).clamp(0, double.infinity),
      fat: toD(raw['fat']).clamp(0, double.infinity),
    );
  }
}

class GroqNutritionService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _chatPath = '/chat/completions';

  /// Disk cache namespace.
  static const String _diskPrefix = 'groq_nutrition_cache_v1:';

  final String model;
  final Duration timeout;

  /// How long a cached result is considered valid.
  final Duration cacheTtl;

  /// Max entries in disk cache (simple LRU-like trimming).
  final int maxDiskEntries;

  /// Enable/disable caching (handy for debugging).
  final bool enableCache;

  GroqNutritionService({
    this.model = 'llama-3.1-8b-instant',
    this.timeout = const Duration(seconds: 25),
    this.cacheTtl = const Duration(days: 7),
    this.maxDiskEntries = 200,
    this.enableCache = true,
  });

  /// In-memory cache for current session.
  final Map<String, _CacheEntry> _memCache = {};

  /// Avoid duplicate API calls for same query concurrently.
  final Map<String, Future<NutritionData?>> _inFlight = {};

  List<String> _loadKeys() {
    final candidates = <String>[
      (dotenv.env['GROQ_API_KEY_1'] ?? '').trim(),
      (dotenv.env['GROQ_API_KEY_2'] ?? '').trim(),
      (dotenv.env['GROQ_API_KEY_3'] ?? '').trim(),

      // optional alternate naming
      (dotenv.env['GROQ_API_KEY1'] ?? '').trim(),
      (dotenv.env['GROQ_API_KEY2'] ?? '').trim(),
      (dotenv.env['GROQ_API_KEY3'] ?? '').trim(),

      // fallback single key if you ever use it
      (dotenv.env['GROQ_API_KEY'] ?? '').trim(),
    ];

    final seen = <String>{};
    final keys = <String>[];
    for (final k in candidates) {
      if (k.isEmpty) continue;
      if (seen.add(k)) keys.add(k);
    }
    return keys;
  }

  /// Public call: returns cached result when available.
  Future<NutritionData?> getNutritionInfo(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    final cacheKey = _makeCacheKey(raw);

    // 1) In-memory cache
    if (enableCache) {
      final mem = _memCache[cacheKey];
      if (mem != null && !_isExpired(mem.savedAtMs)) {
        return mem.data;
      }
    }

    // 2) Disk cache
    if (enableCache) {
      final disk = await _readDiskCache(cacheKey);
      if (disk != null) {
        // promote to memory
        _memCache[cacheKey] = _CacheEntry(disk, diskSavedAtMs: DateTime.now().millisecondsSinceEpoch);
        return disk;
      }
    }

    // 3) In-flight dedupe
    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;

    final future = _fetchAndCache(raw, cacheKey);
    _inFlight[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<NutritionData?> _fetchAndCache(String query, String cacheKey) async {
    final keys = _loadKeys();
    if (keys.isEmpty) {
      log('[Groq] Missing GROQ_API_KEY_1/2/3 in .env');
      return null;
    }

    Object? lastErr;

    for (final key in keys) {
      try {
        final data = await _fetchWithKey(apiKey: key, foodInput: query);
        if (data == null) continue;

        if (enableCache) {
          final now = DateTime.now().millisecondsSinceEpoch;
          _memCache[cacheKey] = _CacheEntry(data, diskSavedAtMs: now);
          await _writeDiskCache(cacheKey, data, now);
        }

        return data;
      } catch (e, st) {
        lastErr = e;
        log('[Groq] Key failed, trying next. err=$e', stackTrace: st);
      }
    }

    log('[Groq] All keys failed. lastErr=$lastErr');
    return null;
  }

  // ------------------ DISK CACHE ------------------

  bool _isExpired(int savedAtMs) {
    final age = DateTime.now().millisecondsSinceEpoch - savedAtMs;
    return age > cacheTtl.inMilliseconds;
    }

  Future<NutritionData?> _readDiskCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = '$_diskPrefix$cacheKey';
      final raw = prefs.getString(k);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final savedAtMs = decoded['savedAtMs'];
      final dataObj = decoded['data'];

      if (savedAtMs is! int || dataObj is! Map) return null;

      if (_isExpired(savedAtMs)) {
        // expired -> remove
        await prefs.remove(k);
        await _touchIndexRemove(prefs, k);
        return null;
      }

      // touch LRU index
      await _touchIndexAdd(prefs, k);

      return NutritionData.fromJson(Map<String, dynamic>.from(dataObj));
    } catch (e) {
      // If disk cache corrupt, fail silently.
      log('[GroqCache] disk read failed: $e');
      return null;
    }
  }

  Future<void> _writeDiskCache(String cacheKey, NutritionData data, int savedAtMs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = '$_diskPrefix$cacheKey';

      final payload = jsonEncode({
        'savedAtMs': savedAtMs,
        'data': data.toJson(),
      });

      await prefs.setString(k, payload);
      await _touchIndexAdd(prefs, k);
      await _trimDiskCacheIfNeeded(prefs);
    } catch (e) {
      log('[GroqCache] disk write failed: $e');
    }
  }

  // Simple index-based trimming (approx LRU)
  static const String _indexKey = 'groq_nutrition_cache_index_v1';

  Future<void> _touchIndexAdd(SharedPreferences prefs, String fullKey) async {
    final list = prefs.getStringList(_indexKey) ?? <String>[];
    // remove if already present
    list.remove(fullKey);
    // add to end (most recent)
    list.add(fullKey);
    await prefs.setStringList(_indexKey, list);
  }

  Future<void> _touchIndexRemove(SharedPreferences prefs, String fullKey) async {
    final list = prefs.getStringList(_indexKey);
    if (list == null) return;
    list.remove(fullKey);
    await prefs.setStringList(_indexKey, list);
  }

  Future<void> _trimDiskCacheIfNeeded(SharedPreferences prefs) async {
    if (maxDiskEntries <= 0) return;

    final list = prefs.getStringList(_indexKey) ?? <String>[];
    if (list.length <= maxDiskEntries) return;

    final overflow = list.length - maxDiskEntries;
    final toRemove = list.take(overflow).toList();
    final remaining = list.skip(overflow).toList();

    for (final k in toRemove) {
      await prefs.remove(k);
    }
    await prefs.setStringList(_indexKey, remaining);
  }

  /// Optional: call this if you want a manual "Clear cache" button.
  Future<void> clearAllCache() async {
    _memCache.clear();
    _inFlight.clear();

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_indexKey) ?? <String>[];
    for (final k in list) {
      await prefs.remove(k);
    }
    await prefs.remove(_indexKey);
  }

  // ------------------ GROQ FETCH ------------------

  Future<NutritionData?> _fetchWithKey({
    required String apiKey,
    required String foodInput,
  }) async {
    final url = Uri.parse('$_baseUrl$_chatPath');

    final grams = _extractGrams(foodInput);

    final systemPrompt = '''
You are a nutrition extractor.
Return ONLY a JSON object (no markdown, no extra text).
All numbers must be >= 0.
If uncertain, make a reasonable estimate.
''';

    final userPrompt = '''
Food input: "$foodInput"
grams_hint: ${grams ?? "null"}

Return JSON with EXACT keys:
{
  "foodName": string,
  "servingSize": string,
  "calories": number,
  "protein": number,
  "carbs": number,
  "fat": number
}
''';

    final payload = <String, dynamic>{
      'model': model,
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      // Best-effort JSON mode (if supported by model)
      'response_format': {'type': 'json_object'},
    };

    final resp = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    // Failover conditions
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw Exception('Groq auth failed (HTTP ${resp.statusCode})');
    }
    if (resp.statusCode == 429) {
      throw Exception('Groq rate limited (HTTP 429)');
    }
    if (resp.statusCode >= 500) {
      throw Exception('Groq server error (HTTP ${resp.statusCode})');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Groq bad response (HTTP ${resp.statusCode}): ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    final content = _extractAssistantContent(decoded);
    if (content == null || content.trim().isEmpty) {
      throw Exception('Groq returned empty content');
    }

    final obj = _parseJsonObject(content);
    if (obj == null) {
      throw Exception('Groq JSON parse failed: $content');
    }

    final data = NutritionData.fromJson(obj);

    // Reject totally empty macro results
    if (data.calories <= 0 &&
        data.protein <= 0 &&
        data.carbs <= 0 &&
        data.fat <= 0) {
      return null;
    }

    return data;
  }

  String? _extractAssistantContent(dynamic decoded) {
    try {
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final msg = choices.first['message'];
      if (msg is! Map) return null;
      final content = msg['content'];
      return content is String ? content : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseJsonObject(String content) {
    // 1) strict JSON
    try {
      final v = jsonDecode(content);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}

    // 2) fallback: first {...} block
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = content.substring(start, end + 1);
      try {
        final v = jsonDecode(slice);
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }
    return null;
  }

  int? _extractGrams(String s) {
    final m = RegExp(r'(\d+(\.\d+)?)\s*(g|gm)\b', caseSensitive: false).firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(1) ?? '')?.round();
  }

  /// Normalize input to reduce duplicate cache entries.
  /// - lowercases
  /// - trims
  /// - collapses whitespace
  /// - keeps numbers/units intact
  String _makeCacheKey(String input) {
    final normalized = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    // Optionally include model, because different models could produce different outputs.
    return 'm=$model|q=$normalized';
  }
}

class _CacheEntry {
  final NutritionData data;

  /// When it was saved (used for TTL). For memory cache, we keep it too.
  final int savedAtMs;

  _CacheEntry(this.data, {required int diskSavedAtMs}) : savedAtMs = diskSavedAtMs;
}
