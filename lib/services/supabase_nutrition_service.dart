import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseNutritionService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get the current user's ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Get today's date in YYYY-MM-DD format (local timezone)
  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Format any DateTime to YYYY-MM-DD format
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get today's nutrition totals from meal_logs
  /// Returns a map with: {calories, protein, carbs, fat}
  Future<Map<String, double>> getTodayTotals() async {
    try {
      if (_currentUserId == null) {
        debugPrint('No user logged in');
        return {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
      }

      final today = _todayDate;
      debugPrint('Fetching totals for date: $today');

      final response = await _client
          .from('meal_logs')
          .select('calories, protein_g, carbs_g, fat_g')
          .eq('user_id', _currentUserId!)
          .eq('activity_date', today);

      if (response == null || response.isEmpty) {
        debugPrint('No meals found for today');
        return {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
      }

      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (var meal in response) {
        totalCalories += _toDouble(meal['calories']);
        totalProtein += _toDouble(meal['protein_g']);
        totalCarbs += _toDouble(meal['carbs_g']);
        totalFat += _toDouble(meal['fat_g']);
      }

      debugPrint('Totals - Cal: $totalCalories, P: $totalProtein, C: $totalCarbs, F: $totalFat');

      return {
        'calories': totalCalories,
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fat': totalFat,
      };
    } catch (e) {
      debugPrint('Error fetching today totals: $e');
      return {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
    }
  }

  /// Get today's meal list
  Future<List<Map<String, dynamic>>> getTodayMeals() async {
    try {
      if (_currentUserId == null) {
        debugPrint('No user logged in');
        return [];
      }

      final today = _todayDate;
      debugPrint('Fetching meals for date: $today');

      final response = await _client
          .from('meal_logs')
          .select('*')
          .eq('user_id', _currentUserId!)
          .eq('activity_date', today)
          .order('created_at', ascending: false);

      if (response == null || response.isEmpty) {
        return [];
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching today meals: $e');
      return [];
    }
  }

  /// Log a meal to the database
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
      if (_currentUserId == null) {
        debugPrint('❌ Error: User not authenticated');
        return false;
      }

      final dateStr = _formatDate(activityDate);

      debugPrint('📝 Attempting to log meal:');
      debugPrint('   User ID: $_currentUserId');
      debugPrint('   Date: $dateStr');
      debugPrint('   Food: $foodName');
      debugPrint('   Calories: $calories');

      // Insert meal log with error details
      final response = await _client.from('meal_logs').insert({
        'user_id': _currentUserId,
        'activity_date': dateStr,
        'food_name': foodName,
        'serving_size': servingSize,
        'calories': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
      }).select();

      debugPrint('✅ Meal logged successfully: $response');

      // Update daily_activities table with the new totals
      await _updateDailyActivities(activityDate);

      debugPrint('✅ Daily activities updated');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('❌ PostgreSQL Error logging meal:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');
      debugPrint('   Hint: ${e.hint}');
      return false;
    } catch (e) {
      debugPrint('❌ Unknown error logging meal: $e');
      debugPrint('   Type: ${e.runtimeType}');
      return false;
    }
  }

  /// Update or create daily_activities record with current day's totals
  Future<void> _updateDailyActivities(DateTime date) async {
    try {
      if (_currentUserId == null) return;

      final dateStr = _formatDate(date);
      final totals = await _getTotalsForDate(dateStr);

      // Check if a record exists for today
      final existing = await _client
          .from('daily_activities')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('activity_date', dateStr)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _client
            .from('daily_activities')
            .update({
              'calories_consumed': totals['calories']!.toInt(),
              'protein_consumed': totals['protein']!.toInt(),
              'carbs_consumed': totals['carbs']!.toInt(),
              'fat_consumed': totals['fat']!.toInt(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
      } else {
        // Create new record
        await _client.from('daily_activities').insert({
          'user_id': _currentUserId,
          'activity_date': dateStr,
          'calories_consumed': totals['calories']!.toInt(),
          'protein_consumed': totals['protein']!.toInt(),
          'carbs_consumed': totals['carbs']!.toInt(),
          'fat_consumed': totals['fat']!.toInt(),
        });
      }
    } catch (e) {
      debugPrint('Error updating daily_activities: $e');
    }
  }

  /// Get totals for a specific date
  Future<Map<String, double>> _getTotalsForDate(String dateStr) async {
    try {
      final response = await _client
          .from('meal_logs')
          .select('calories, protein_g, carbs_g, fat_g')
          .eq('user_id', _currentUserId!)
          .eq('activity_date', dateStr);

      if (response == null || response.isEmpty) {
        return {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
      }

      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (var meal in response) {
        totalCalories += _toDouble(meal['calories']);
        totalProtein += _toDouble(meal['protein_g']);
        totalCarbs += _toDouble(meal['carbs_g']);
        totalFat += _toDouble(meal['fat_g']);
      }

      return {
        'calories': totalCalories,
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fat': totalFat,
      };
    } catch (e) {
      debugPrint('Error getting totals for date: $e');
      return {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
    }
  }

  /// Delete a meal by ID
  Future<bool> deleteMeal(String mealId) async {
    try {
      if (_currentUserId == null) return false;

      // Get the meal's date before deleting
      final meal = await _client
          .from('meal_logs')
          .select('activity_date')
          .eq('id', mealId)
          .single();

      await _client.from('meal_logs').delete().eq('id', mealId);

      // Update daily_activities after deletion
      if (meal != null && meal['activity_date'] != null) {
        final date = DateTime.parse(meal['activity_date']);
        await _updateDailyActivities(date);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting meal: $e');
      return false;
    }
  }

  /// Helper to convert dynamic values to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Get nutrition data for a specific date range
  Future<Map<String, dynamic>> getDateRangeNutrition(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      if (_currentUserId == null) return {};

      final start = _formatDate(startDate);
      final end = _formatDate(endDate);

      final response = await _client
          .from('meal_logs')
          .select('activity_date, calories, protein_g, carbs_g, fat_g')
          .eq('user_id', _currentUserId!)
          .gte('activity_date', start)
          .lte('activity_date', end)
          .order('activity_date', ascending: true);

      if (response == null || response.isEmpty) return {};

      // Group by date
      Map<String, Map<String, double>> dailyTotals = {};

      for (var meal in response) {
        final date = meal['activity_date'] as String;
        if (!dailyTotals.containsKey(date)) {
          dailyTotals[date] = {
            'calories': 0.0,
            'protein': 0.0,
            'carbs': 0.0,
            'fat': 0.0,
          };
        }
        dailyTotals[date]!['calories'] = 
            (dailyTotals[date]!['calories'] ?? 0) + _toDouble(meal['calories']);
        dailyTotals[date]!['protein'] = 
            (dailyTotals[date]!['protein'] ?? 0) + _toDouble(meal['protein_g']);
        dailyTotals[date]!['carbs'] = 
            (dailyTotals[date]!['carbs'] ?? 0) + _toDouble(meal['carbs_g']);
        dailyTotals[date]!['fat'] = 
            (dailyTotals[date]!['fat'] ?? 0) + _toDouble(meal['fat_g']);
      }

      return dailyTotals;
    } catch (e) {
      debugPrint('Error fetching date range nutrition: $e');
      return {};
    }
  }
}