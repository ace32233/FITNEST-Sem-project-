import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// --- IMPORTS ---
import 'intro_page.dart';
import 'calorie_page.dart'; 
import 'water_reminder.dart'; 
import 'personalized_exercise_screen.dart'; 
import 'services/user_goals_service.dart';
import 'services/step_service.dart';
import 'profile_page.dart'; 

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kGlassBorder = Color(0x1AFFFFFF); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kAccentBlue = Color(0xFF3B82F6); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

// --- DATA MODEL FOR PRE-LOADING ---
class DashboardData {
  final int waterIntake;
  final int waterGoal;
  final int calories;
  final int caloriesGoal;
  final int protein;
  final int proteinGoal;
  final int carbs;
  final int carbsGoal;
  final int fat;
  final int fatGoal;
  final int streak;
  final int stepsCount;
  final int stepsGoal;

  DashboardData({
    this.waterIntake = 0,
    this.waterGoal = 3000,
    this.calories = 0,
    this.caloriesGoal = 2500,
    this.protein = 0,
    this.proteinGoal = 150,
    this.carbs = 0,
    this.carbsGoal = 250,
    this.fat = 0,
    this.fatGoal = 70,
    this.streak = 0,
    this.stepsCount = 0,
    this.stepsGoal = 10000,
  });
}

// ==========================================
// 1. THE MAIN CONTROLLER (STATE CONTAINER)
// ==========================================
class HomePage extends StatefulWidget {
  final DashboardData? initialData; 

  const HomePage({super.key, this.initialData});

  static Future<DashboardData> preloadData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return DashboardData();

      final today = DateTime.now().toIso8601String().split('T')[0];
      final goalsService = UserGoalsService();

      final results = await Future.wait<dynamic>([
        goalsService.getUserGoals(), 
        supabase.from('daily_activities').select().eq('user_id', userId).eq('activity_date', today).maybeSingle() as Future<Map<String, dynamic>?>, 
        supabase.from('meal_logs').select().eq('user_id', userId).gte('activity_date', today).lt('activity_date', DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0]) as Future<List<dynamic>>, 
        supabase.from('user_streaks').select().eq('user_id', userId).maybeSingle() as Future<Map<String, dynamic>?>, 
      ]);

      final goals = results[0] as Map<String, dynamic>?;
      final activity = results[1] as Map<String, dynamic>?;
      final meals = results[2] as List<dynamic>;
      final streakRes = results[3] as Map<String, dynamic>?;

      double cals = 0, prot = 0, carbs = 0, fat = 0;
      for (var m in meals) {
        cals += (m['calories'] ?? 0);
        prot += (m['protein_g'] ?? 0);
        carbs += (m['carbs_g'] ?? 0);
        fat += (m['fat_g'] ?? 0);
      }

      return DashboardData(
        waterIntake: (activity?['water_intake_ml'] ?? 0).toInt(),
        waterGoal: (activity?['water_goal_ml'] ?? 3000).toInt(),
        calories: cals.toInt(),
        caloriesGoal: (goals?['calories_goal'] ?? 2500).toInt(),
        protein: prot.toInt(),
        proteinGoal: (goals?['protein_goal_g'] ?? 150).toInt(),
        carbs: carbs.toInt(),
        carbsGoal: (goals?['carbs_goal_g'] ?? 250).toInt(),
        fat: fat.toInt(),
        fatGoal: (goals?['fat_goal_g'] ?? 70).toInt(),
        streak: (streakRes?['current_streak'] ?? 0).toInt(),
        stepsCount: (activity?['steps_count'] ?? 0).toInt(),
        stepsGoal: (activity?['steps_goal'] ?? 10000).toInt(),
      );
    } catch (e) {
      debugPrint("Error pre-loading data: $e");
      return DashboardData();
    }
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;

  // State Variables 
  late int _waterIntake;
  late int _waterGoal;
  late int _caloriesConsumed;
  late int _caloriesGoal;
  late int _proteinConsumed;
  late int _proteinGoal;
  late int _fatConsumed;
  late int _fatGoal;
  late int _carbsConsumed;
  late int _carbsGoal;
  late int _currentStreak;

  // ✅ Step counter state
  int _currentSteps = 0;
  int _stepsGoal = 10000;
  Timer? _stepRefreshTimer;

  // ✅ Keep pages alive
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? DashboardData();
    _waterIntake = data.waterIntake;
    _waterGoal = data.waterGoal;
    _caloriesConsumed = data.calories;
    _caloriesGoal = data.caloriesGoal;
    _proteinConsumed = data.protein;
    _proteinGoal = data.proteinGoal;
    _fatConsumed = data.fat;
    _fatGoal = data.fatGoal;
    _carbsConsumed = data.carbs;
    _carbsGoal = data.carbsGoal;
    _currentStreak = data.streak;
    _currentSteps = data.stepsCount;
    _stepsGoal = data.stepsGoal;

    // ✅ Initialize persistent pages once (excluding home page which rebuilds with state)
    _pages = [
      Container(), // Placeholder, will be replaced in build
      NutritionPage(),
      WaterTrackerPage(),
      const PersonalizedExerciseScreen(),
      const ProfilePage(),
    ];

    if (widget.initialData == null) {
      _refreshData(); 
    }

    // ✅ Load step goal and start monitoring
    _loadStepGoal();
    _startStepMonitoring();
  }

  @override
  void dispose() {
    _stepRefreshTimer?.cancel();
    super.dispose();
  }

  // ✅ Load step goal from database
  Future<void> _loadStepGoal() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];
      final activity = await _supabase
          .from('daily_activities')
          .select('steps_goal')
          .eq('user_id', userId)
          .eq('activity_date', today)
          .maybeSingle();

      if (activity != null) {
        setState(() {
          _stepsGoal = (activity['steps_goal'] ?? 10000).toInt();
        });
      } else {
        // Create today's activity record if it doesn't exist
        await _createTodayActivity();
      }
    } catch (e) {
      debugPrint('Error loading step goal: $e');
    }
  }

  // ✅ Create today's activity record
  Future<void> _createTodayActivity() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      await _supabase.from('daily_activities').insert({
        'user_id': userId,
        'activity_date': today,
        'steps_count': 0,
        'steps_goal': _stepsGoal,
      });
    } catch (e) {
      debugPrint('Error creating today activity: $e');
    }
  }

  // ✅ Save step goal to database
  Future<void> _saveStepGoal(int goal) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];

      setState(() {
        _stepsGoal = goal;
      });

      // Update in database
      await _supabase.from('daily_activities').upsert({
        'user_id': userId,
        'activity_date': today,
        'steps_goal': goal,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,activity_date');

    } catch (e) {
      debugPrint('Error saving step goal: $e');
    }
  }

  // ✅ Start monitoring steps from the service and save to database
  void _startStepMonitoring() {
    // Update immediately
    _updateSteps();
    
    // Refresh every 5 seconds to keep UI updated and save to database
    _stepRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (mounted) {
        _updateSteps();
        await _saveStepsToDatabase();
      }
    });
  }

  // ✅ Update steps from the service
  void _updateSteps() {
    setState(() {
      _currentSteps = StepService.instance.todaySteps;
    });
  }

  // ✅ Save steps to database
  Future<void> _saveStepsToDatabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Upsert the step count (StepService handles midnight reset automatically)
      await _supabase.from('daily_activities').upsert({
        'user_id': userId,
        'activity_date': today,
        'steps_count': _currentSteps,
        'steps_goal': _stepsGoal,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,activity_date');

    } catch (e) {
      debugPrint('Error saving steps to database: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh when switching back to Home to catch any goal updates
    if (index == 0) {
      _refreshData();
      _updateSteps();
    }
  }

  Future<void> _refreshData() async {
    final data = await HomePage.preloadData();
    if(mounted) {
      setState(() {
         _waterIntake = data.waterIntake;
        _waterGoal = data.waterGoal;
        _caloriesConsumed = data.calories;
        _caloriesGoal = data.caloriesGoal;
        _proteinConsumed = data.protein;
        _proteinGoal = data.proteinGoal;
        _fatConsumed = data.fat;
        _fatGoal = data.fatGoal;
        _carbsConsumed = data.carbs;
        _carbsGoal = data.carbsGoal;
        _currentStreak = data.streak;
        _currentSteps = data.stepsCount;
        _stepsGoal = data.stepsGoal;
      });
    }
  }

  void _showEditStepsGoalDialog() {
    final controller = TextEditingController(text: _stepsGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Steps Goal", style: TextStyle(color: kTextWhite)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: kTextWhite),
          decoration: InputDecoration(
            hintText: "Enter steps goal",
            hintStyle: TextStyle(color: kTextGrey.withOpacity(0.5)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kGlassBorder)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kAccentCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: kTextGrey)),
          ),
          TextButton(
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                await _saveStepGoal(val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: kAccentCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update home page in the list (it needs to rebuild with state changes)
    _pages[0] = _buildHomePage();
    
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text("Dashboard", style: TextStyle(color: kTextWhite, fontWeight: FontWeight.w700, fontSize: 22)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kDarkTeal, kDarkSlate],
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: _buildGlossyBottomBar(),
    );
  }

  Widget _buildGlossyBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kGlassBorder, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 0),
              _buildNavItem(Icons.restaurant_menu_rounded, 1),
              _buildNavItem(Icons.water_drop_rounded, 2),
              _buildNavItem(Icons.fitness_center_rounded, 3),
              _buildNavItem(Icons.person_rounded, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: isSelected
            ? BoxDecoration(
                gradient: const LinearGradient(colors: [kAccentCyan, kAccentBlue]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
              )
            : null,
        child: Icon(icon, color: isSelected ? kTextWhite : kTextGrey, size: 24),
      ),
    );
  }

  Widget _buildHomePage() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _refreshData();
          _updateSteps();
        },
        backgroundColor: kCardSurface,
        color: kAccentCyan,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStreakCard(),
              const SizedBox(height: 20),
              GlossyWaterCard(
                consumed: _waterIntake,
                goal: _waterGoal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaterTrackerPage())),
              ),
              const SizedBox(height: 16),
              GlossyStepsCard(
                steps: _currentSteps,
                goal: _stepsGoal,
                onEdit: _showEditStepsGoalDialog,
              ),
              const SizedBox(height: 24),
              _buildNutritionCard(
                protein: _proteinConsumed,
                proteinGoal: _proteinGoal,
                carbs: _carbsConsumed,
                carbsGoal: _carbsGoal,
                fat: _fatConsumed,
                fatGoal: _fatGoal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
            child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Current Streak", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text("$_currentStreak Days", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
        ],
      ),
    );
  }

  Widget _buildNutritionCard({
    required int protein,
    required int proteinGoal,
    required int carbs,
    required int carbsGoal,
    required int fat,
    required int fatGoal,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NutritionPage())),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardSurface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kGlassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Nutrition", style: TextStyle(color: kTextWhite, fontSize: 18, fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: kAccentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text("${_caloriesConsumed}/${_caloriesGoal} kcal", style: const TextStyle(color: kAccentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 8,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double progress = (_caloriesGoal > 0) ? (_caloriesConsumed / _caloriesGoal).clamp(0.0, 1.0) : 0.0;
                  return Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.green, Colors.greenAccent]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: kGlassBorder, height: 1),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactMacro("Protein", protein, proteinGoal, kAccentCyan),
                _buildCompactMacro("Carbs", carbs, carbsGoal, Colors.purpleAccent),
                _buildCompactMacro("Fat", fat, fatGoal, Colors.orangeAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMacro(String label, int value, int goal, Color color) {
    double progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kTextGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "$value/${goal}g",
          style: const TextStyle(
            color: kTextWhite,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 4,
          width: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GlossyWaterCard extends StatelessWidget {
  final int consumed;
  final int goal;
  final VoidCallback onTap;

  const GlossyWaterCard({super.key, required this.consumed, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (goal > 0) ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: kCardSurface.withOpacity(0.6), 
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kGlassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kAccentBlue.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: kAccentBlue.withOpacity(0.3)),
              ),
              child: const Icon(Icons.water_drop_rounded, color: kAccentBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hydration", style: TextStyle(color: kTextWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: "$consumed", style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.bold)),
                        TextSpan(text: " / $goal ml", style: TextStyle(color: kTextGrey.withOpacity(0.7))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 45,
                  width: 45,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation(kAccentBlue),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text("${(progress * 100).toInt()}%", style: const TextStyle(fontSize: 10, color: kAccentBlue, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GlossyStepsCard extends StatelessWidget {
  final int steps;
  final int goal;
  final VoidCallback onEdit;

  const GlossyStepsCard({
    super.key, 
    required this.steps, 
    required this.goal,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.6), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
            ),
            child: const Icon(Icons.directions_walk_rounded, color: Colors.pinkAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Steps", style: TextStyle(color: kTextWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                    GestureDetector(
                      onTap: onEdit,
                      child: const Icon(Icons.edit_rounded, color: kTextGrey, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: "$steps", style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.bold)),
                      TextSpan(text: " / ${_formatGoal(goal)}", style: TextStyle(color: kTextGrey.withOpacity(0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (goal > 0 ? steps / goal : 0.0).clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  String _formatGoal(int goal) {
    if (goal >= 1000) {
      return "${(goal / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k";
    }
    return "$goal";
  }
}