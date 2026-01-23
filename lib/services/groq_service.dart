import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
}

class GroqNutritionService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _chatPath = '/chat/completions';

  final String model;
  final Duration timeout;

  GroqNutritionService({
    this.model = 'llama-3.1-8b-instant',
    this.timeout = const Duration(seconds: 25),
  });

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

  Future<NutritionData?> getNutritionInfo(String input) async {
    final q = input.trim();
    if (q.isEmpty) return null;

    final keys = _loadKeys();
    if (keys.isEmpty) {
      log('[Groq] Missing GROQ_API_KEY_1/2/3 in .env');
      return null;
    }

    Object? lastErr;

    for (final key in keys) {
      try {
        final data = await _fetchWithKey(apiKey: key, foodInput: q);
        if (data != null) return data;
      } catch (e, st) {
        lastErr = e;
        log('[Groq] Key failed, trying next. err=$e', stackTrace: st);
      }
    }

    log('[Groq] All keys failed. lastErr=$lastErr');
    return null;
  }

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

    final data = _normalize(obj);

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

  NutritionData _normalize(Map<String, dynamic> raw) {
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

  int? _extractGrams(String s) {
    final m = RegExp(r'(\d+(\.\d+)?)\s*(g|gm)\b', caseSensitive: false).firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(1) ?? '')?.round();
  }
}
