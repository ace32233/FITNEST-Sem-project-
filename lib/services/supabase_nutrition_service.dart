import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNutritionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user ID
  String? get userId => _supabase.auth.currentUser?.id;

  // Add meal to meal_logs table
  Future<bool> logMeal({
    required String foodName,
    required String servingSize,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required DateTime activityDate,
  }) async {
    try {
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('meal_logs').insert({
        'user_id': userId,
        'activity_date': activityDate.toIso8601String().split('T')[0],
        'food_name': foodName,
        'serving_size': servingSize,
        'calories': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
      });

      // Update daily_activities table
      await updateDailyActivities(
        activityDate: activityDate,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );

      return true;
    } catch (e) {
      print('Error logging meal: $e');
      return false;
    }
  }

  // Update or create daily_activities record
  Future<void> updateDailyActivities({
    required DateTime activityDate,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    if (userId == null) return;

    final dateStr = activityDate.toIso8601String().split('T')[0];

    // Check if record exists for today
    final existing = await _supabase
        .from('daily_activities')
        .select()
        .eq('user_id', userId!)
        .eq('activity_date', dateStr)
        .maybeSingle();

    if (existing == null) {
      // Create new record
      await _supabase.from('daily_activities').insert({
        'user_id': userId,
        'activity_date': dateStr,
        'calories_consumed': calories.toInt(),
        'protein_consumed': protein.toInt(),
        'carbs_consumed': carbs.toInt(),
        'fat_consumed': fat.toInt(),
      });
    } else {
      // Update existing record
      await _supabase
          .from('daily_activities')
          .update({
            'calories_consumed': (existing['calories_consumed'] ?? 0) + calories.toInt(),
            'protein_consumed': (existing['protein_consumed'] ?? 0) + protein.toInt(),
            'carbs_consumed': (existing['carbs_consumed'] ?? 0) + carbs.toInt(),
            'fat_consumed': (existing['fat_consumed'] ?? 0) + fat.toInt(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id']);
    }
  }

  // Fetch today's meal logs
  Future<List<Map<String, dynamic>>> getTodayMeals() async {
    if (userId == null) return [];

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('meal_logs')
          .select()
          .eq('user_id', userId!)
          .eq('activity_date', today)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching meals: $e');
      return [];
    }
  }

  // Fetch today's nutrition totals
  Future<Map<String, dynamic>> getTodayTotals() async {
    if (userId == null) {
      return {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      };
    }

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('daily_activities')
          .select()
          .eq('user_id', userId!)
          .eq('activity_date', today)
          .maybeSingle();

      if (response == null) {
        return {
          'calories': 0,
          'protein': 0,
          'carbs': 0,
          'fat': 0,
        };
      }

      return {
        'calories': response['calories_consumed'] ?? 0,
        'protein': response['protein_consumed'] ?? 0,
        'carbs': response['carbs_consumed'] ?? 0,
        'fat': response['fat_consumed'] ?? 0,
      };
    } catch (e) {
      print('Error fetching totals: $e');
      return {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      };
    }
  }

  // Delete a meal log
  Future<bool> deleteMeal(String mealId) async {
    try {
      await _supabase.from('meal_logs').delete().eq('id', mealId);
      return true;
    } catch (e) {
      print('Error deleting meal: $e');
      return false;
    }
  }
}