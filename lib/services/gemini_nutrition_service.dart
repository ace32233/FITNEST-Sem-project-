import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

// Keep your NutritionData class exactly as it is (no changes needed there)
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
  // Your working API Key
  static const String apiKey = 'AIzaSyAj1xbZrrIKQTAa_WCDvI1bWl-6HfQ3c30';
  late final GenerativeModel _model;

  GeminiNutritionService() {
    
    _model = GenerativeModel(
      model: 'gemini-2.5-pro', 
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
  "serving_size": "string (e.g., '100g' or '1 cup')",
  "calories": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number
}
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null) return null;

      // Clean the response
      String cleanJson = response.text!.replaceAll(RegExp(r'```json|```'), '').trim();
      
      // Extract just the JSON part { ... }
      int start = cleanJson.indexOf('{');
      int end = cleanJson.lastIndexOf('}');
      if (start != -1 && end != -1) {
        cleanJson = cleanJson.substring(start, end + 1);
      }

      return NutritionData.fromJson(json.decode(cleanJson));
    } catch (e) {
      print('Gemini Error: $e');
      return null;
    }
  }
}