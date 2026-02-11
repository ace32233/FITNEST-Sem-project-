import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; 
import 'dart:math' as math;
import 'dart:async';
import 'services/supabase_nutrition_service.dart';
import 'services/user_goals_service.dart';
import 'services/groq_service.dart';

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38);
const Color kDarkSlate = Color(0xFF0F172A);
const Color kCardSurface = Color(0xFF1E293B);
const Color kGlassBorder = Color(0x33FFFFFF);
const Color kGlassBase = Color(0x1AFFFFFF);
const Color kAccentCyan = Color(0xFF22D3EE);
const Color kAccentBlue = Color(0xFF3B82F6);
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

class NutritionPage extends StatefulWidget {
  final Function(double calories, double protein, double carbs, double fat)? onDataChanged;

  const NutritionPage({super.key, this.onDataChanged});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  // --- Services ---
  final GroqNutritionService _nutritionService = GroqNutritionService();
  final SupabaseNutritionService _supabaseService = SupabaseNutritionService();
  final UserGoalsService _goalsService = UserGoalsService();

  // --- Controllers ---
  final TextEditingController _searchController = TextEditingController();

  // --- State Variables ---
  double caloriesValue = 0;
  double caloriesLimit = 2500;
  double proteinValue = 0;
  double carbsValue = 0;
  double fatValue = 0;

  double proteinTarget = 150;
  double carbsTarget = 250;
  double fatTarget = 70;

  List<Map<String, dynamic>> foodLog = [];
  bool isLoading = false;
  bool isCalculating = false;

  // --- Midnight Reset Variables ---
  Timer? _midnightTimer;
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTodayData();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _midnightTimer?.cancel();
    super.dispose();
  }

  // --- MIDNIGHT RESET LOGIC ---
  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    debugPrint('Scheduling midnight reset in ${durationUntilMidnight.inMinutes} minutes');

    _midnightTimer = Timer(durationUntilMidnight, () {
      _handleMidnightReset();
      _scheduleMidnightReset(); // Schedule the next one
    });
  }

  Future<void> _handleMidnightReset() async {
    debugPrint('Midnight reset triggered at ${DateTime.now()}');
    
    final previousDate = _currentDate;
    _currentDate = DateTime.now();

    // Check if it's actually a new day
    if (previousDate.year == _currentDate.year &&
        previousDate.month == _currentDate.month &&
        previousDate.day == _currentDate.day) {
      debugPrint('False alarm - still the same day');
      return;
    }

    // Reset local state
    if (mounted) {
      setState(() {
        caloriesValue = 0;
        proteinValue = 0;
        carbsValue = 0;
        fatValue = 0;
        foodLog = [];
      });

      // Notify parent of reset
      widget.onDataChanged?.call(0, 0, 0, 0);

      // Reload today's data (which should be empty for new day)
      await _loadTodayData(silent: true);

      // Show a subtle notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('New day started! Your nutrition tracker has been reset.'),
            backgroundColor: kAccentCyan,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // --- HELPERS ---
  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  // --- BACKEND LOGIC: LOAD DATA ---
  Future<void> _loadTodayData({bool silent = false}) async {
    if (!silent) {
      setState(() => isLoading = true);
    }

    try {
      // Load user goals
      try {
        final goalsData = await _goalsService.getUserGoals();
        if (goalsData != null) {
          setState(() {
            caloriesLimit = _toDouble(goalsData['calories_goal'] ?? 2500);
            proteinTarget = _toDouble(goalsData['protein_goal_g'] ?? 150);
            carbsTarget = _toDouble(goalsData['carbs_goal_g'] ?? 250);
            fatTarget = _toDouble(goalsData['fat_goal_g'] ?? 70);
          });
        }
      } catch (e) {
        debugPrint("Could not load goals from API, using defaults.");
      }

      // Load today's nutrition data
      final totals = await _supabaseService.getTodayTotals();
      final meals = await _supabaseService.getTodayMeals();

      if (mounted) {
        setState(() {
          caloriesValue = _toDouble(totals['calories']);
          proteinValue = _toDouble(totals['protein']);
          carbsValue = _toDouble(totals['carbs']);
          fatValue = _toDouble(totals['fat']);
          foodLog = meals;
          isLoading = false; 
        });

        // Trigger callback to parent
        widget.onDataChanged?.call(
          caloriesValue, 
          proteinValue, 
          carbsValue, 
          fatValue
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Failed to load data');
      }
    }
  }

  // --- BACKEND LOGIC: ADD MEAL ---
  Future<void> _addMeal(String input) async {
    if (input.trim().isEmpty) return;

    setState(() => isCalculating = true);

    try {
      final nutritionData = await _nutritionService.getNutritionInfo(input);

      if (nutritionData == null) {
        _showErrorSnackBar('Could not fetch nutrition data. Please try again.');
        setState(() => isCalculating = false);
        return;
      }

      bool badNum(double v) => v.isNaN || v.isInfinite || v < 0;
      final foodName = nutritionData.foodName.trim();
      final serving = nutritionData.servingSize.trim();

      if (foodName.isEmpty ||
          badNum(nutritionData.calories) ||
          badNum(nutritionData.protein) ||
          badNum(nutritionData.carbs) ||
          badNum(nutritionData.fat)) {
        _showErrorSnackBar('Nutrition data looks invalid. Try a different food.');
        setState(() => isCalculating = false);
        return;
      }

      final success = await _supabaseService.logMeal(
        foodName: foodName,
        servingSize: serving.isEmpty ? '1 serving' : serving,
        calories: nutritionData.calories,
        protein: nutritionData.protein,
        carbs: nutritionData.carbs,
        fat: nutritionData.fat,
        activityDate: DateTime.now(),
      );

      if (!success) {
        setState(() => isCalculating = false);
        _showErrorSnackBar('Failed to save meal');
        return;
      }

      _searchController.clear();
      await _loadTodayData(silent: true); // Triggers callback inside

      setState(() => isCalculating = false);
    } catch (e) {
      setState(() => isCalculating = false);
      _showErrorSnackBar('An error occurred. Please try again.');
    }
  }

  // --- GLOSSY DIALOG ---
  void _showSetLimitsDialog() {
    final calController =
        TextEditingController(text: caloriesLimit.toInt().toString());
    final proController =
        TextEditingController(text: proteinTarget.toInt().toString());
    final carbController =
        TextEditingController(text: carbsTarget.toInt().toString());
    final fatController =
        TextEditingController(text: fatTarget.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: kDarkSlate.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: kGlassBorder),
          ),
          title: const Text("Set Nutrition Goals",
              style: TextStyle(color: kTextWhite, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGoalInput("Calories", calController),
                const SizedBox(height: 12),
                _buildGoalInput("Protein (g)", proController),
                const SizedBox(height: 12),
                _buildGoalInput("Carbs (g)", carbController),
                const SizedBox(height: 12),
                _buildGoalInput("Fat (g)", fatController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: kTextGrey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newCalories =
                    double.tryParse(calController.text) ?? caloriesLimit;
                final newProtein =
                    double.tryParse(proController.text) ?? proteinTarget;
                final newCarbs =
                    double.tryParse(carbController.text) ?? carbsTarget;
                final newFat = double.tryParse(fatController.text) ?? fatTarget;

                setState(() {
                  caloriesLimit = newCalories;
                  proteinTarget = newProtein;
                  carbsTarget = newCarbs;
                  fatTarget = newFat;
                });

                try {
                  await _goalsService.updateUserGoals(
                    caloriesGoal: newCalories.toInt(),
                    proteinGoal: newProtein.toInt(),
                    carbsGoal: newCarbs.toInt(),
                    fatGoal: newFat.toInt(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Goals updated successfully!"),
                        backgroundColor: kAccentCyan,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showErrorSnackBar("Failed to update goals. Try again.");
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: kTextWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kTextGrey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGlassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGlassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAccentCyan, width: 2),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkTeal,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccentCyan))
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  // --- APP BAR ---
                  SliverAppBar(
                    floating: true,
                    backgroundColor: kDarkTeal,
                    elevation: 0,
                    title: const Text(
                      "Nutrition Tracker",
                      style: TextStyle(
                        color: kTextWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.tune, color: kAccentCyan),
                        onPressed: _showSetLimitsDialog,
                        tooltip: "Set Goals",
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // --- CONTENT ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- PROGRESS CARD ---
                          _buildProgressCard(),
                          const SizedBox(height: 24),

                          // --- INPUT SEARCH BAR ---
                          _buildSearchBar(),
                          const SizedBox(height: 24),

                          // --- FOOD LOG ---
                          const Text(
                            "Today's Meals",
                            style: TextStyle(
                              color: kTextWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (foodLog.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(Icons.restaurant_menu,
                                      size: 48, color: kTextGrey.withOpacity(0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No meals logged yet",
                                    style: TextStyle(
                                      color: kTextGrey.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...foodLog.map((meal) => GlossyMealTile(meal: meal)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: kDarkSlate.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGlassBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: kTextWhite),
        decoration: InputDecoration(
          hintText: "Search food or add meal...",
          hintStyle: TextStyle(color: kTextGrey.withOpacity(0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: isCalculating
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: kAccentCyan,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.add_circle, color: kAccentCyan, size: 28),
                  onPressed: () => _addMeal(_searchController.text),
                ),
        ),
        onSubmitted: _addMeal,
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress =
        caloriesLimit > 0 ? (caloriesValue / caloriesLimit).clamp(0.0, 1.0) : 0.0;
    final consumed = caloriesValue.toInt();
    final goal = caloriesLimit.toInt();
    final protein = proteinValue.toInt();
    final carbs = carbsValue.toInt();
    final fat = fatValue.toInt();
    final proteinGoal = proteinTarget.toInt();
    final carbsGoal = carbsTarget.toInt();
    final fatGoal = fatTarget.toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kDarkSlate.withOpacity(0.8),
            kCardSurface.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: kGlassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- TITLE ROW ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Daily Calories",
                style: TextStyle(
                  color: kTextWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kAccentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kAccentCyan.withOpacity(0.3)),
                ),
                child: Text(
                  "${DateTime.now().day}/${DateTime.now().month}",
                  style: const TextStyle(
                    color: kAccentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- PROGRESS BAR ---
          Stack(
            children: [
              // Background Track
              Container(
                height: 24,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Foreground Fill
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
              // Text inside bar (Percent & Total)
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
          const SizedBox(height: 16),

          // --- MACROS (Responsive Horizontal Rows) ---
          _buildMacroRow("Protein", protein, proteinGoal, kAccentCyan),
          const SizedBox(height: 12),
          _buildMacroRow("Carbs", carbs, carbsGoal, Colors.purpleAccent),
          const SizedBox(height: 12),
          _buildMacroRow("Fat", fat, fatGoal, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, int value, int goal, Color color) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        // Responsive Label
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: kTextGrey, fontSize: 13)),
        ),
        // Bar
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Responsive Value
        Expanded(
          flex: 3,
          child: Text(
            "$value / ${goal}g",
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: kTextWhite,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class GlossyMealTile extends StatelessWidget {
  final Map<String, dynamic> meal;

  const GlossyMealTile({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final name = (meal['food_name'] as String? ?? 'Meal').toLowerCase();
    IconData icon = Icons.restaurant;
    Color iconColor = kAccentBlue;

    if (name.contains('break')) {
      icon = Icons.wb_sunny_rounded;
      iconColor = Colors.orange;
    } else if (name.contains('lunch')) {
      icon = Icons.wb_twilight_rounded;
      iconColor = Colors.yellow;
    } else if (name.contains('dinner')) {
      icon = Icons.nights_stay_rounded;
      iconColor = Colors.indigoAccent;
    } else if (name.contains('snack')) {
      icon = Icons.cookie_rounded;
      iconColor = Colors.pinkAccent;
    } else if (name.contains('egg') || name.contains('chicken') || name.contains('beef')) {
      icon = Icons.restaurant_menu_rounded;
    } else if (name.contains('water') || name.contains('drink')) {
      icon = Icons.local_drink_rounded;
      iconColor = Colors.cyan;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSlate.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal['food_name'] ?? 'Unknown Meal',
                  style: const TextStyle(
                    color: kTextWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${meal['calories']} kcal • ${meal['serving_size']}",
                  style: TextStyle(
                    color: kAccentCyan.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("P: ${meal['protein_g']}g", style: const TextStyle(color: kTextGrey, fontSize: 11)),
              Text("C: ${meal['carbs_g']}g", style: const TextStyle(color: kTextGrey, fontSize: 11)),
              Text("F: ${meal['fat_g']}g", style: const TextStyle(color: kTextGrey, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }
}