import 'package:supabase_flutter/supabase_flutter.dart';

class UserGoalsService {
  final _supabase = Supabase.instance.client;

  /// Get user's nutrition goals from database
  Future<Map<String, dynamic>?> getUserGoals() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('user_nutrition_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error getting user goals: $e');
      return null;
    }
  }

  /// Update or create user's nutrition goals
  Future<bool> updateUserGoals({
    required int caloriesGoal,
    required int proteinGoal,
    required int carbsGoal,
    required int fatGoal,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Check if goals exist
      final existing = await _supabase
          .from('user_nutrition_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Insert new goals
        await _supabase.from('user_nutrition_goals').insert({
          'user_id': userId,
          'calories_goal': caloriesGoal,
          'protein_goal_g': proteinGoal,
          'carbs_goal_g': carbsGoal,
          'fat_goal_g': fatGoal,
        });
      } else {
        // Update existing goals
        await _supabase
            .from('user_nutrition_goals')
            .update({
              'calories_goal': caloriesGoal,
              'protein_goal_g': proteinGoal,
              'carbs_goal_g': carbsGoal,
              'fat_goal_g': fatGoal,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      }

      // Also update today's daily_activities goal
      final today = DateTime.now().toIso8601String().split('T')[0];
      await _supabase.from('daily_activities').upsert({
        'user_id': userId,
        'activity_date': today,
        'calories_goal': caloriesGoal,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error updating user goals: $e');
      return false;
    }
  }

  /// Get default goals (fallback values)
  Map<String, int> getDefaultGoals() {
    return {
      'calories': 2500,
      'protein': 150,
      'carbs': 250,
      'fat': 70,
    };
  }
}