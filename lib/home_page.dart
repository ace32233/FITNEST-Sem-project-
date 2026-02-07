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

    if (widget.initialData == null) {
      _refreshData(); 
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh when switching back to Home to catch any goal updates
    if (index == 0) {
      _refreshData();
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
      });
    }
  }

  void _updateWater(int newAmount) {
    setState(() => _waterIntake = newAmount);
    _refreshData(); // Refresh to sync goals/streak if needed
  }

  void _updateNutrition(double cals, double prot, double carbs, double fat) {
    setState(() {
      _caloriesConsumed = cals.toInt();
      _proteinConsumed = prot.toInt();
      _carbsConsumed = carbs.toInt();
      _fatConsumed = fat.toInt();
    });
    _refreshData(); // Refresh to sync goals/streak if needed
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeDashboard(
        onNavigate: _onItemTapped,
        waterIntake: _waterIntake,
        waterGoal: _waterGoal,
        calories: _caloriesConsumed,
        caloriesGoal: _caloriesGoal,
        protein: _proteinConsumed,
        proteinGoal: _proteinGoal,
        carbs: _carbsConsumed,
        carbsGoal: _carbsGoal,
        fat: _fatConsumed,
        fatGoal: _fatGoal,
        streak: _currentStreak, 
      ),
      NutritionPage(onDataChanged: _updateNutrition),
      // ✅ FIX: Pass the refresh callback to update streak instantly
      PersonalizedExerciseScreen(onWorkoutCompleted: _refreshData),
      WaterTrackerPage(onWaterChanged: _updateWater),
      const ProfilePage(),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kDarkSlate, kDarkTeal], 
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 75,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 20),
            decoration: BoxDecoration(
              color: kDarkSlate.withOpacity(0.95),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: kGlassBorder, width: 0.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, "Home"),
                    _buildNavItem(1, Icons.restaurant_menu_rounded, "Food"),
                    _buildNavItem(2, Icons.fitness_center_rounded, "Workout"),
                    _buildNavItem(3, Icons.water_drop_rounded, "Water"),
                    _buildNavItem(4, Icons.person_rounded, "Profile"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isActive ? BoxDecoration(
          color: kAccentCyan.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kAccentCyan.withOpacity(0.2)),
        ) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isActive ? kAccentCyan : kTextGrey.withOpacity(0.7)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? kAccentCyan : kTextGrey.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. THE DASHBOARD (UPDATED)
// ==========================================
class HomeDashboard extends StatefulWidget {
  final Function(int) onNavigate;
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

  const HomeDashboard({
    super.key,
    required this.onNavigate,
    required this.waterIntake,
    required this.waterGoal,
    required this.calories,
    required this.caloriesGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
    required this.streak,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _steps = 0; 
  int _stepGoal = 10000;
  late StreamSubscription<StepCount> _stepCountSubscription;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
    _initPedometer();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if(mounted) setState(() => _stepGoal = prefs.getInt('daily_step_goal') ?? 10000);
  }

  Future<void> _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountSubscription = Pedometer.stepCountStream.listen(_onStepCount, onError: (e) {});
    }
  }

  void _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    int? baseline = prefs.getInt('steps_at_midnight_$todayKey');
    if (baseline == null) {
      baseline = event.steps;
      await prefs.setInt('steps_at_midnight_$todayKey', event.steps);
    }
    int todaySteps = event.steps - baseline;
    if (todaySteps < 0) { todaySteps = event.steps; await prefs.setInt('steps_at_midnight_$todayKey', 0); }
    if (mounted) setState(() => _steps = todaySteps);
  }

  @override
  void dispose() {
    try { _stepCountSubscription.cancel(); } catch(e){}
    super.dispose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  void _showStepGoalDialog() {
    final controller = TextEditingController(text: _stepGoal.toString());
    showDialog(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: kCardSurface.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: kGlassBorder)),
            title: const Text('Set Daily Step Goal', style: TextStyle(color: kTextWhite)),
            content: TextField(controller: controller, keyboardType: TextInputType.number, style: const TextStyle(color: kTextWhite), decoration: InputDecoration(filled: true, fillColor: Colors.white.withOpacity(0.05))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: kTextGrey))),
              ElevatedButton(onPressed: () async {
                final newGoal = int.tryParse(controller.text) ?? 10000;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('daily_step_goal', newGoal);
                setState(() => _stepGoal = newGoal);
                if(mounted) Navigator.pop(context);
              }, style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: kDarkSlate), child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(getGreeting(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kTextWhite, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 16, color: widget.streak > 0 ? Colors.orange : kTextGrey),
                  const SizedBox(width: 4),
                  Text(widget.streak > 0 ? "${widget.streak} Day Streak" : "Start your streak!", style: TextStyle(fontSize: 14, color: widget.streak > 0 ? kTextWhite : kTextGrey, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            GlossyCalorieCard(
              consumed: widget.calories,
              goal: widget.caloriesGoal,
              protein: widget.protein,
              proteinGoal: widget.proteinGoal,
              fat: widget.fat,
              fatGoal: widget.fatGoal,
              carbs: widget.carbs,
              carbsGoal: widget.carbsGoal,
              onTap: () => widget.onNavigate(1), 
            ),
            const SizedBox(height: 20),
            GlossyWaterCard(
              consumed: widget.waterIntake,
              goal: widget.waterGoal,
              onTap: () => widget.onNavigate(3), 
            ),
            const SizedBox(height: 20),
            GlossyStepsCard(steps: _steps, goal: _stepGoal, onEdit: _showStepGoalDialog),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS ---

class GlossyCalorieCard extends StatelessWidget {
  final int consumed;
  final int goal;
  final int protein;
  final int proteinGoal;
  final int fat;
  final int fatGoal;
  final int carbs;
  final int carbsGoal;
  final VoidCallback onTap;

  const GlossyCalorieCard({
    super.key,
    required this.consumed,
    required this.goal,
    required this.protein,
    required this.proteinGoal,
    required this.fat,
    required this.fatGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final int remaining = goal - consumed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardSurface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: kGlassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_fire_department_rounded,
                          color: Colors.orangeAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Calories",
                      style: TextStyle(
                        color: kTextWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: kTextGrey, size: 16),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  remaining >= 0 ? "$remaining" : "0",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: kTextWhite,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "kcal left",
                    style: TextStyle(
                      fontSize: 16,
                      color: kTextGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 24,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 24,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kAccentCyan, kAccentBlue],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: kAccentCyan.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${(progress * 100).toInt()}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                          ),
                        ),
                        Text(
                          "$consumed / $goal",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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