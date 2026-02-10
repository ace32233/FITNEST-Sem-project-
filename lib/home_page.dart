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
import 'services/step_service.dart'; // ✅ Added
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

  // ✅ Step counter state
  int _currentSteps = 0;
  int _stepsGoal = 10000;
  Timer? _stepRefreshTimer;

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

    // ✅ Load step goal and start monitoring
    _loadStepGoal();
    _startStepMonitoring();
  }

  @override
  void dispose() {
    _stepRefreshTimer?.cancel();
    super.dispose();
  }

  // ✅ Load step goal from SharedPreferences
  Future<void> _loadStepGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _stepsGoal = prefs.getInt('steps_goal') ?? 10000;
      });
    } catch (e) {
      debugPrint('Error loading step goal: $e');
    }
  }

  // ✅ Save step goal to SharedPreferences
  Future<void> _saveStepGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('steps_goal', goal);
      setState(() {
        _stepsGoal = goal;
      });
    } catch (e) {
      debugPrint('Error saving step goal: $e');
    }
  }

  // ✅ Start monitoring steps from the service
  void _startStepMonitoring() {
    // Update immediately
    _updateSteps();
    
    // Refresh every 2 seconds to keep UI updated
    _stepRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _updateSteps();
      }
    });
  }

  // ✅ Update steps from the service
  void _updateSteps() {
    setState(() {
      _currentSteps = StepService.instance.todaySteps;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh when switching back to Home to catch any goal updates
    if (index == 0) {
      _refreshData();
      _updateSteps(); // ✅ Also refresh steps
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

  // ✅ Show dialog to edit step goal
  void _showEditStepGoalDialog() {
    final controller = TextEditingController(text: _stepsGoal.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardSurface,
        title: const Text('Edit Step Goal', style: TextStyle(color: kTextWhite)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: kTextWhite),
          decoration: InputDecoration(
            hintText: 'Enter step goal',
            hintStyle: TextStyle(color: kTextGrey.withOpacity(0.5)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: kGlassBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: kAccentCyan),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kTextGrey)),
          ),
          TextButton(
            onPressed: () {
              final newGoal = int.tryParse(controller.text);
              if (newGoal != null && newGoal > 0) {
                _saveStepGoal(newGoal);
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: kAccentCyan)),
          ),
        ],
      ),
    );
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
        // ✅ Pass step data
        steps: _currentSteps,
        stepsGoal: _stepsGoal,
        onEditStepGoal: _showEditStepGoalDialog,
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kCardSurface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: kGlassBorder, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  selectedItemColor: kAccentCyan,
                  unselectedItemColor: kTextGrey.withOpacity(0.6),
                  selectedFontSize: 12,
                  unselectedFontSize: 11,
                  showSelectedLabels: true,
                  showUnselectedLabels: false,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 26), label: 'Home'),
                    BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded, size: 26), label: 'Nutrition'),
                    BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded, size: 26), label: 'Exercise'),
                    BottomNavigationBarItem(icon: Icon(Icons.water_drop_rounded, size: 26), label: 'Water'),
                    BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 26), label: 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. HOME DASHBOARD (UI ONLY)
// ==========================================
class HomeDashboard extends StatelessWidget {
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
  // ✅ Step counter props
  final int steps;
  final int stepsGoal;
  final VoidCallback onEditStepGoal;

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
    required this.steps,
    required this.stepsGoal,
    required this.onEditStepGoal,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildGreeting(),
            const SizedBox(height: 12),
            _buildStreakBanner(),
            const SizedBox(height: 24),
            GlossyNutritionCard(
              calories: calories,
              caloriesGoal: caloriesGoal,
              protein: protein,
              proteinGoal: proteinGoal,
              carbs: carbs,
              carbsGoal: carbsGoal,
              fat: fat,
              fatGoal: fatGoal,
              onTap: () => onNavigate(1),
            ),
            const SizedBox(height: 16),
            GlossyWaterCard(
              consumed: waterIntake,
              goal: waterGoal,
              onTap: () => onNavigate(3),
            ),
            const SizedBox(height: 16),
            // ✅ Updated step card with real data
            GlossyStepsCard(
              steps: steps,
              goal: stepsGoal,
              onEdit: onEditStepGoal,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? "Good Morning"
        : hour < 17
            ? "Good Afternoon"
            : "Good Evening";
    return Text(
      greeting,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: kTextWhite,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStreakBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kAccentCyan.withOpacity(0.2), kAccentBlue.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Current Streak", style: TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  "$streak ${streak == 1 ? 'day' : 'days'}",
                  style: const TextStyle(color: kTextWhite, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ... (Rest of the file remains exactly the same as your original)
// Including GlossyNutritionCard, GlossyWaterCard, GlossyStepsCard classes

class GlossyNutritionCard extends StatelessWidget {
  final int calories;
  final int caloriesGoal;
  final int protein;
  final int proteinGoal;
  final int carbs;
  final int carbsGoal;
  final int fat;
  final int fatGoal;
  final VoidCallback onTap;

  const GlossyNutritionCard({
    super.key,
    required this.calories,
    required this.caloriesGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.local_dining_rounded, color: Colors.greenAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Nutrition",
                      style: TextStyle(color: kTextWhite, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: kTextGrey, size: 16),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Calories",
                        style: TextStyle(color: kTextGrey, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "$calories",
                              style: const TextStyle(color: kTextWhite, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: " / $caloriesGoal kcal",
                              style: TextStyle(color: kTextGrey.withOpacity(0.7), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (caloriesGoal > 0 ? calories / caloriesGoal : 0.0).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.greenAccent],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
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