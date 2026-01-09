import 'dart:convert';
import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class NutritionData {
  final String foodName;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionData({
    required this.foodName,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    return NutritionData(
      foodName: json['food_name'] ?? '',
      servingSize: json['serving_size'] ?? '',
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein_g'] ?? 0).toDouble(),
      carbs: (json['carbs_g'] ?? 0).toDouble(),
      fat: (json['fat_g'] ?? 0).toDouble(),
    );
  }
}

class GeminiNutritionService {
  late final GenerativeModel _model;

  GeminiNutritionService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
  }

  Future<NutritionData?> getNutritionInfo(String foodInput) async {
    try {
      final prompt = '''
Analyze the following food item: "$foodInput"

Return the data as a strictly valid JSON object.
Do not include markdown formatting, backticks, or any preamble.
If the food is unknown, return null for the numeric values.

{
  "food_name": "string",
  "serving_size": "string",
  "calories": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number
}
''';

      final response = await _model.generateContent(
        [Content.text(prompt)],
      );

      if (response.text == null) return null;

      String cleanJson =
          response.text!.replaceAll(RegExp(r'```json|```'), '').trim();

      final start = cleanJson.indexOf('{');
      final end = cleanJson.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      cleanJson = cleanJson.substring(start, end + 1);

      return NutritionData.fromJson(json.decode(cleanJson));
    } catch (e) {
      log('Gemini Error', error: e);
      return null;
    }
  }
}
