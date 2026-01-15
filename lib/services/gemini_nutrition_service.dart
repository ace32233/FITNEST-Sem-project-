import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class NutritionData {
  final String foodName;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool isValid;

  const NutritionData({
    required this.foodName,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.isValid = true,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    final calories = _toDouble(json['calories']);
    final protein = _toDouble(json['protein_g']);
    final carbs = _toDouble(json['carbs_g']);
    final fat = _toDouble(json['fat_g']);

    // valid if any macro/calorie is > 0 and is_valid is not false
    final bool ok = (json['is_valid'] != false) &&
        (calories > 0 || protein > 0 || carbs > 0 || fat > 0);

    return NutritionData(
      foodName: (json['food_name'] ?? '').toString(),
      servingSize: (json['serving_size'] ?? '').toString(),
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      isValid: ok,
    );
  }
}

class GeminiNutritionService {
  late final GenerativeModel _model;

  GeminiNutritionService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // ✅ best for your use
      apiKey: apiKey.trim(),
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 300,
        // ✅ forces JSON output (prevents parsing issues)
        responseMimeType: 'application/json',
      ),
    );
  }

  bool _isValidFoodInput(String input) {
    final s = input.trim();
    if (s.isEmpty) return false;
    if (s.length > 200) return false;

    // block obvious injection / urls
    final suspicious = RegExp(
      r'(<script\b|</\w+>|http[s]?:\/\/|www\.|\bselect\b|\bdrop\b|\binsert\b|\bdelete\b|\bupdate\b|;--|\bunion\b)',
      caseSensitive: false,
    );
    return !suspicious.hasMatch(s);
  }

  String _prompt(String foodInput) => '''
Return nutrition facts for a user-entered food line.

Input: "$foodInput"

If input is NOT a food or beverage item, return ONLY:
{"is_valid": false}

If valid, return ONLY JSON exactly like:
{
  "is_valid": true,
  "food_name": "clear food name",
  "serving_size": "quantity specified or a reasonable standard serving",
  "calories": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number
}
''';

  /// ✅ This matches your NutritionPage code (returns NutritionData?).
  Future<NutritionData?> getNutritionInfo(String foodInput) async {
    try {
      if (!_isValidFoodInput(foodInput)) {
        log('GeminiNutritionService: rejected input="$foodInput"');
        return null;
      }

      final response = await _model.generateContent([Content.text(_prompt(foodInput))]);
      final text = response.text;

      if (text == null || text.trim().isEmpty) {
        log('GeminiNutritionService: empty response');
        return null;
      }

      // responseMimeType=json should already be clean JSON, but still guard.
      final cleaned = text.trim();

      final decoded = json.decode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        log('GeminiNutritionService: JSON is not an object. raw="$cleaned"');
        return null;
      }

      if (decoded['is_valid'] == false) {
        log('GeminiNutritionService: model marked invalid');
        return null;
      }

      final data = NutritionData.fromJson(decoded);
      if (!data.isValid) {
        log('GeminiNutritionService: parsed but invalid macros');
        return null;
      }

      return data;
    } on GenerativeAIException catch (e) {
      log('GeminiNutritionService: Gemini API error: ${e.message}', error: e);
      return null;
    } on FormatException catch (e) {
      log('GeminiNutritionService: JSON parse error', error: e);
      return null;
    } catch (e) {
      log('GeminiNutritionService: unexpected error', error: e);
      return null;
    }
  }
}
