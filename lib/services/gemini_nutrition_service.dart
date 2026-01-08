import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'food_name': foodName,
      'serving_size': servingSize,
      'calories': calories,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
    };
  }
}

class GeminiNutritionService {
  static const String apiKey = 'AIzaSyAj1xbZrrIKQTAa_WCDvI1bWl-6HfQ3c30';
  late final GenerativeModel _model;

  GeminiNutritionService() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: apiKey,
    );
  }

  Future<NutritionData?> getNutritionInfo(String foodInput) async {
    try {
      final prompt = '''
You are a nutrition expert. Analyze the following food input and provide accurate nutritional information.

Food input: "$foodInput"

Please provide the nutritional information in the following JSON format ONLY. Do not include any other text, explanations, or markdown formatting:

{
  "food_name": "name of the food item",
  "serving_size": "the serving size mentioned (e.g., '200g', '1 cup', '2 pieces')",
  "calories": numeric value in kcal,
  "protein_g": numeric value in grams,
  "carbs_g": numeric value in grams,
  "fat_g": numeric value in grams
}

Rules:
- If no quantity is specified, assume a standard serving size
- Provide realistic and accurate nutritional values based on USDA or common nutrition databases
- All numeric values should be numbers, not strings
- Round values to 1 decimal place
- Return only valid JSON, no additional text
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini API');
      }

      // Clean the response text
      String jsonText = response.text!.trim();
      
      // Remove markdown code blocks if present
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      
      jsonText = jsonText.trim();

      // Parse JSON
      final Map<String, dynamic> nutritionJson = json.decode(jsonText);
      
      return NutritionData.fromJson(nutritionJson);
    } catch (e) {
      print('Error getting nutrition info: $e');
      return null;
    }
  }
}