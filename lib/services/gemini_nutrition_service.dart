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
  final bool isValid;

  NutritionData({
    required this.foodName,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.isValid = true,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    // Check if the response indicates invalid/unknown food
    final calories = json['calories'];
    final protein = json['protein_g'];
    final carbs = json['carbs_g'];
    final fat = json['fat_g'];
    
    // If all nutritional values are null or 0, it's likely invalid
    final isValid = calories != null && 
                    (calories is num && calories > 0 ||
                     protein is num && protein > 0 ||
                     carbs is num && carbs > 0 ||
                     fat is num && fat > 0);

    return NutritionData(
      foodName: json['food_name'] ?? '',
      servingSize: json['serving_size'] ?? '',
      calories: (calories ?? 0).toDouble(),
      protein: (protein ?? 0).toDouble(),
      carbs: (carbs ?? 0).toDouble(),
      fat: (fat ?? 0).toDouble(),
      isValid: isValid,
    );
  }

  factory NutritionData.invalid() {
    return NutritionData(
      foodName: '',
      servingSize: '',
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      isValid: false,
    );
  }
}

class GeminiNutritionService {
  late final GenerativeModel _model;
  
  // Cache for common invalid inputs
  static final Set<String> _invalidInputPatterns = {
    'sql', 'select', 'drop', 'table', 'database',
    'script', 'alert', 'javascript', 'html',
    'http://', 'https://', 'www.',
  };

  GeminiNutritionService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1, // Lower temperature for more consistent output
        maxOutputTokens: 500,
      ),
    );
  }

  /// Validates input before sending to API
  bool _isValidFoodInput(String input) {
    if (input.trim().isEmpty) return false;
    if (input.length > 200) return false; // Prevent excessively long inputs
    
    final lowerInput = input.toLowerCase();
    
    // Check for suspicious patterns
    if (_invalidInputPatterns.any((pattern) => lowerInput.contains(pattern))) {
      return false;
    }
    
    // Check for excessive special characters (possible injection attempts)
    final specialCharCount = RegExp(r'[^a-zA-Z0-9\s,.-]').allMatches(input).length;
    if (specialCharCount > input.length * 0.3) return false;
    
    return true;
  }

  Future<NutritionData?> getNutritionInfo(String foodInput) async {
    try {
      // Pre-validation
      if (!_isValidFoodInput(foodInput)) {
        log('Invalid food input detected: $foodInput');
        return null;
      }

      final prompt = '''
You are a nutrition information assistant. Analyze ONLY if the input is a valid food item with optional quantity.

Input: "$foodInput"

STRICT RULES:
1. ONLY respond if the input is a legitimate food or beverage item
2. Reject if input contains: code, URLs, commands, nonsense text, or non-food items
3. Accept quantities like "2 apples", "1 cup rice", "100g chicken"
4. If invalid or not food-related, return: {"is_valid": false}
5. For valid food, return ONLY this JSON structure with NO markdown or extra text:

{
  "is_valid": true,
  "food_name": "clear food name",
  "serving_size": "quantity specified or standard serving",
  "calories": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number
}

Return ONLY the JSON object, nothing else.
''';

      final response = await _model.generateContent(
        [Content.text(prompt)],
      );

      if (response.text == null || response.text!.isEmpty) {
        log('Empty response from Gemini');
        return null;
      }

      // Clean the response
      String cleanJson = response.text!
          .replaceAll(RegExp(r'```json|```'), '')
          .trim();

      // Extract JSON object
      final start = cleanJson.indexOf('{');
      final end = cleanJson.lastIndexOf('}');
      
      if (start == -1 || end == -1) {
        log('No valid JSON found in response');
        return null;
      }

      cleanJson = cleanJson.substring(start, end + 1);

      final jsonData = json.decode(cleanJson) as Map<String, dynamic>;
      
      // Check if the API marked it as invalid
      if (jsonData['is_valid'] == false) {
        log('API marked input as invalid food item');
        return null;
      }

      final nutritionData = NutritionData.fromJson(jsonData);
      
      // Final validation check
      if (!nutritionData.isValid) {
        log('Nutrition data validation failed');
        return null;
      }

      return nutritionData;
      
    } on FormatException catch (e) {
      log('JSON parsing error', error: e);
      return null;
    } on GenerativeAIException catch (e) {
      log('Gemini API error', error: e);
      return null;
    } catch (e) {
      log('Unexpected error in getNutritionInfo', error: e);
      return null;
    }
  }
}
