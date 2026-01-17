import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'dart:async';

// --- IMPORT YOUR OTHER PAGES HERE ---
import 'intro_page.dart';
import 'calorie_page.dart'; 
import 'water_reminder.dart'; 
import 'personalized_exercise_screen.dart'; 
import 'services/user_goals_service.dart';

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kGlassBorder = Color(0x1AFFFFFF); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kAccentBlue = Color(0xFF3B82F6); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

// ==========================================
// 1. THE MAIN CONTROLLER (THE SHELL)
// ==========================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- FIX: Define pages here so we can pass 'isVisible' status ---
    // We pass 'true' to HomeDashboard only if _selectedIndex == 0
    final List<Widget> pages = [
      HomeDashboard(isVisible: _selectedIndex == 0), // 0: Home
      const NutritionPage(),                         // 1: Food
      const PersonalizedExerciseScreen(),            // 2: Workout
      const WaterTrackerPage(),                      // 3: Water
      const Scaffold(backgroundColor: Colors.transparent, body: Center(child: Text("Stats Coming Soon", style: TextStyle(color: Colors.white)))), // 4: Stats
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

        // --- GLOBAL NAVIGATION BAR ---
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 75,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              color: kDarkSlate.withOpacity(0.95),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: kGlassBorder, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
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
                    _buildNavItem(4, Icons.bar_chart_rounded, "Stats"),
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
            Icon(
              icon, 
              size: 24, 
              color: isActive ? kAccentCyan : kTextGrey.withOpacity(0.7)
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? kAccentCyan : kTextGrey.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. THE HOME DASHBOARD
// ==========================================
class HomeDashboard extends StatefulWidget {
  // --- FIX: Add isVisible parameter ---
  final bool isVisible;
  const HomeDashboard({super.key, required this.isVisible});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _supabase = Supabase.instance.client;
  final _goalsService = UserGoalsService();

  // Data variables
  int _currentStreak = 0;
  int _steps = 0;
  int _caloriesConsumed = 0;
  int _caloriesGoal = 2500;
  int _proteinConsumed = 0;
  int _proteinGoal = 150;
  int _fatConsumed = 0;
  int _fatGoal = 70;
  int _carbsConsumed = 0;
  int _carbsGoal = 250;
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

  // --- FIX: ADD THIS METHOD ---
  // This detects when the Home Page becomes visible again (e.g., coming back from Nutrition Page)
  @override
  void didUpdateWidget(HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the page just became visible, reload the data
    if (widget.isVisible && !oldWidget.isVisible) {
      _loadData();
    }
  }

  @override
  void dispose() {
    try {
      _stepCountSubscription.cancel();
    } catch (e) { /* ignore */ }
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        behavior: SnackBarBehavior.floating, 
        margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _initStepCounter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final savedDate = prefs.getString('step_date') ?? '';

      if (savedDate != today) {
        await prefs.setString('step_date', today);
        await prefs.setInt('initial_steps', 0);
        _initialSteps = 0;
        _isStepCounterInitialized = false;
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
    if (!mounted) return;
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

      final goalsData = await _goalsService.getUserGoals();
      if (goalsData != null && mounted) {
        setState(() {
          _caloriesGoal = goalsData['calories_goal'] ?? 2500;
          _proteinGoal = goalsData['protein_goal_g'] ?? 150;
          _carbsGoal = goalsData['carbs_goal_g'] ?? 250;
          _fatGoal = goalsData['fat_goal_g'] ?? 70;
        });
      }

      final streakData = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (streakData != null && mounted) {
        setState(() {
          _currentStreak = streakData['current_streak'] ?? 0;
        });
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final activityData = await _supabase
          .from('daily_activities')
          .select()
          .eq('user_id', userId)
          .eq('activity_date', today)
          .maybeSingle();

      if (activityData != null && mounted) {
        setState(() {
          _waterIntake = activityData['water_intake_ml'] ?? 0;
          _waterGoal = activityData['water_goal_ml'] ?? 3000;
        });
      }

      final nutritionTotals = await _supabase
          .from('meal_logs')
          .select('calories, protein_g, carbs_g, fat_g')
          .eq('user_id', userId)
          .gte('activity_date', today)
          .lt('activity_date', DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0]);

      if (nutritionTotals.isNotEmpty && mounted) {
        double totalCalories = 0;
        double totalProtein = 0;
        double totalCarbs = 0;
        double totalFat = 0;

        for (var meal in nutritionTotals) {
          totalCalories += (meal['calories'] ?? 0).toDouble();
          totalProtein += (meal['protein_g'] ?? 0).toDouble();
          totalCarbs += (meal['carbs_g'] ?? 0).toDouble();
          totalFat += (meal['fat_g'] ?? 0).toDouble();
        }

        setState(() {
          _caloriesConsumed = totalCalories.toInt();
          _proteinConsumed = totalProtein.toInt();
          _carbsConsumed = totalCarbs.toInt();
          _fatConsumed = totalFat.toInt();
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _showSignOutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                  side: const BorderSide(color: kGlassBorder)
              ),
              title: const Text('Sign Out', style: TextStyle(color: kTextWhite, fontWeight: FontWeight.bold)),
              content: const Text('Are you sure you want to sign out?', style: TextStyle(color: kTextGrey)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: kTextGrey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      _showErrorSnackBar('Error signing out: $e');
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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
              Text(
                getGreeting(),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kTextWhite, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 16, color: _currentStreak > 0 ? Colors.orange : kTextGrey),
                  const SizedBox(width: 4),
                  Text(
                    _currentStreak > 0 ? "$_currentStreak Day Streak" : "Start your streak!",
                    style: TextStyle(fontSize: 14, color: _currentStreak > 0 ? kTextWhite : kTextGrey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: kGlassBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: kTextGrey, size: 20),
              onPressed: _showSignOutDialog,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: kAccentCyan,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              GlossyCalorieCard(
                consumed: _caloriesConsumed,
                goal: _caloriesGoal,
                protein: _proteinConsumed,
                proteinGoal: _proteinGoal,
                fat: _fatConsumed,
                fatGoal: _fatGoal,
                carbs: _carbsConsumed,
                carbsGoal: _carbsGoal,
                onTap: () {}, 
              ),
              const SizedBox(height: 20),
              GlossyWaterCard(
                consumed: _waterIntake,
                goal: _waterGoal,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              GlossyStepsCard(steps: _steps),
              const SizedBox(height: 120),
            ],
          ),
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
    final progress = (goal > 0) ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = goal - consumed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardSurface.withOpacity(0.6), 
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: kGlassBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 25, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: kAccentCyan.withOpacity(0.15), blurRadius: 50, spreadRadius: -10),
                    ],
                  ),
                ),
                SizedBox(
                  height: 190,
                  width: 190,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 18,
                    color: Colors.white.withOpacity(0.05),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                SizedBox(
                  height: 190,
                  width: 190,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        colors: [kAccentCyan, kAccentBlue],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(rect);
                    },
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 18,
                      backgroundColor: Colors.transparent,
                      color: Colors.white,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      remaining >= 0 ? "$remaining" : "Over",
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: kTextWhite, height: 1.0),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Kcal Left",
                      style: TextStyle(fontSize: 14, color: kTextGrey.withOpacity(0.8), letterSpacing: 1.2),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GlossyMacroTile("Protein", "$protein/${proteinGoal}g", kAccentCyan),
                Container(width: 1, height: 30, color: kGlassBorder),
                GlossyMacroTile("Fat", "$fat/${fatGoal}g", Colors.orangeAccent),
                Container(width: 1, height: 30, color: kGlassBorder),
                GlossyMacroTile("Carbs", "$carbs/${carbsGoal}g", Colors.purpleAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GlossyMacroTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const GlossyMacroTile(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: kTextGrey.withOpacity(0.8), fontSize: 12),
            ),
          ],
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
  const GlossyStepsCard({super.key, required this.steps});

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
                const Text("Steps", style: TextStyle(color: kTextWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: "$steps", style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.bold)),
                      TextSpan(text: " / 10k", style: TextStyle(color: kTextGrey.withOpacity(0.7))),
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
              widthFactor: (steps / 10000).clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }
}