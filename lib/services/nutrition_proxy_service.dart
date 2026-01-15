import 'dart:convert';
import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    return NutritionData(
      foodName: (json['food_name'] ?? '').toString(),
      servingSize: (json['serving_size'] ?? '').toString(),
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fat: (json['fat_g'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NutritionProxyService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<NutritionData?> getNutritionInfo(String input) async {
    final q = input.trim();
    if (q.isEmpty) return null;

    try {
      final res = await _sb.functions.invoke(
        'fatsecret-nutrition',
        body: {'query': q},
      );

      if (res.data == null) {
        log('fatsecret-nutrition: null data');
        return null;
      }

      final data = res.data is String ? jsonDecode(res.data) : res.data;

      // backend can return { ok:false, error:"..." }
      if (data is Map && data['ok'] == false) {
        log('fatsecret-nutrition error: ${data['error']}');
        return null;
      }

      if (data is Map<String, dynamic>) {
        return NutritionData.fromJson(data);
      }

      return null;
    } catch (e) {
      log('NutritionProxyService error: $e');
      return null;
    }
  }
}
