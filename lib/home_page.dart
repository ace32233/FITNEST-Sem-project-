import 'package:flutter/material.dart';
import 'calorie_page.dart';
import 'water_reminder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'dart:async';
import 'intro_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  
  // Data variables
  int _currentStreak = 0;
  int _steps = 0;
  final int _caloriesConsumed = 0;
  int _caloriesGoal = 2670;
  final int _proteinConsumed = 0;
  final int _fatConsumed = 0;
  final int _carbsConsumed = 0;
  int _waterIntake = 0;
  int _waterGoal = 3000;
  
  // Step counter
  late StreamSubscription<StepCount> _stepCountSubscription;
  int _initialSteps = 0;
  bool _isStepCounterInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initStepCounter();
  }

  @override
  void dispose() {
    _stepCountSubscription.cancel();
    super.dispose();
  }

  Future<void> _initStepCounter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final savedDate = prefs.getString('step_date') ?? '';
      
      // Reset steps if it's a new day
      if (savedDate != today) {
        await prefs.setString('step_date', today);
        await prefs.setInt('initial_steps', 0);
        _initialSteps = 0;
      } else {
        _initialSteps = prefs.getInt('initial_steps') ?? 0;
      }

      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
      );
    } catch (e) {
      debugPrint('Error initializing step counter: $e');
    }
  }

  void _onStepCount(StepCount event) async {
    if (!_isStepCounterInitialized) {
      final prefs = await SharedPreferences.getInstance();
      _initialSteps = event.steps;
      await prefs.setInt('initial_steps', _initialSteps);
      _isStepCounterInitialized = true;
    }

    setState(() {
      _steps = event.steps - _initialSteps;
    });
  }

  void _onStepCountError(error) {
    debugPrint('Step Count Error: $error');
  }

  Future<void> _loadData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load streak data
      final streakData = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (streakData != null) {
        setState(() {
          _currentStreak = streakData['current_streak'] ?? 0;
        });
      }

      // Load today's activity data
      final today = DateTime.now().toIso8601String().split('T')[0];
      final activityData = await _supabase
          .from('daily_activities')
          .select()
          .eq('user_id', userId)
          .eq('activity_date', today)
          .maybeSingle();

      if (activityData != null) {
        setState(() {
          _caloriesGoal = activityData['calories_goal'] ?? 2670;
          _waterIntake = activityData['water_intake_ml'] ?? 0;
          _waterGoal = activityData['water_goal_ml'] ?? 3000;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _updateStreak() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Check if streak exists
      final existingStreak = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existingStreak == null) {
        // Create new streak
        await _supabase.from('user_streaks').insert({
          'user_id': userId,
          'current_streak': 1,
          'longest_streak': 1,
          'last_activity_date': today,
          'streak_start_date': today,
          'total_active_days': 1,
        });
        setState(() => _currentStreak = 1);
      } else {
        final lastActivityDate = existingStreak['last_activity_date'];
        final lastDate = DateTime.parse(lastActivityDate);
        final todayDate = DateTime.parse(today);
        final difference = todayDate.difference(lastDate).inDays;

        int newStreak = existingStreak['current_streak'];
        
        if (difference == 1) {
          // Continue streak
          newStreak += 1;
        } else if (difference > 1) {
          // Reset streak
          newStreak = 1;
        }

        final longestStreak = newStreak > existingStreak['longest_streak']
            ? newStreak
            : existingStreak['longest_streak'];

        await _supabase.from('user_streaks').update({
          'current_streak': newStreak,
          'longest_streak': longestStreak,
          'last_activity_date': today,
          'total_active_days': existingStreak['total_active_days'] + 1,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);

        setState(() => _currentStreak = newStreak);
      }
    } catch (e) {
      debugPrint('Error updating streak: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const IntroPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Add Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddOption(
                  icon: Icons.restaurant,
                  label: 'Calories',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NutritionPage(),
                      ),
                    );
                  },
                ),
                _buildAddOption(
                  icon: Icons.water_drop,
                  label: 'Water',
                  color: Colors.cyan,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WaterTrackerPage(),
                      ),
                    );
                    _addWater();
                  },
                ),
                _buildAddOption(
                  icon: Icons.fitness_center,
                  label: 'Exercise',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to exercise input screen
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addWater() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];
      final newWaterIntake = _waterIntake + 250; // Add 250ml

      await _supabase.from('daily_activities').upsert({
        'user_id': userId,
        'activity_date': today,
        'water_intake_ml': newWaterIntake,
        'water_goal_ml': _waterGoal,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _waterIntake = newWaterIntake;
      });

      await _updateStreak();
    } catch (e) {
      debugPrint('Error adding water: $e');
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning ☀️";
    if (hour < 17) return "Good Afternoon 🌤️";
    return "Good Evening 🌙";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getGreeting(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _currentStreak > 0 ? "🔥 $_currentStreak Day Streak" : "Start your streak today!",
              style: TextStyle(
                fontSize: 12,
                color: _currentStreak > 0 ? Colors.orange : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CalorieDashboardCard(
                consumed: _caloriesConsumed,
                goal: _caloriesGoal,
                protein: _proteinConsumed,
                fat: _fatConsumed,
                carbs: _carbsConsumed,
              ),
              const SizedBox(height: 16),
              WaterTrackerCard(
                consumed: _waterIntake,
                goal: _waterGoal,
              ),
              const SizedBox(height: 16),
              StepsCard(steps: _steps),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1E293B),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: Colors.blue, size: 28),
                onPressed: () {},
              ),
              const SizedBox(width: 40), // Space for FAB
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white, size: 28),
                onPressed: () {
                  // TODO: Navigate to stats page
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalorieDashboardCard extends StatelessWidget {
  final int consumed;
  final int goal;
  final int protein;
  final int fat;
  final int carbs;

  const CalorieDashboardCard({
    super.key,
    required this.consumed,
    required this.goal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = goal - consumed;
    final progress = consumed / goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 14,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 1 ? Colors.red : Colors.blue,
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    remaining >= 0 ? remaining.toString() : "Over!",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    remaining >= 0 ? "Remaining" : "${-remaining} over",
                    style: TextStyle(
                      color: remaining >= 0 ? Colors.grey : Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroTile("Calories", "$consumed / $goal", Colors.blue),
              MacroTile("Protein", "$protein g", Colors.green),
              MacroTile("Fat", "$fat g", Colors.orange),
              MacroTile("Carbs", "$carbs g", Colors.purple),
            ],
          ),
        ],
      ),
    );
  }
}

class WaterTrackerCard extends StatelessWidget {
  final int consumed;
  final int goal;

  const WaterTrackerCard({
    super.key,
    required this.consumed,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final progress = consumed / goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Water Intake",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$consumed / $goal ml",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${(progress * 100).toInt()}% Complete",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              const Icon(Icons.water_drop, color: Colors.blue, size: 32),
            ],
          ),
        ],
      ),
    );
  }
}

class StepsCard extends StatelessWidget {
  final int steps;

  const StepsCard({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    const goal = 10000;
    final progress = steps / goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Steps",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  "Goal: 10,000",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
                ),
              ),
              const Icon(Icons.directions_walk, color: Colors.pink, size: 32),
            ],
          ),
        ],
      ),
    );
  }
}

class MacroTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MacroTile(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}