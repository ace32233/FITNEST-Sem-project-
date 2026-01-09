import 'package:fittness_app/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'water_reminder.dart';
import 'services/gemini_nutrition_service.dart';
import 'services/supabase_nutrition_service.dart';
import 'services/user_goals_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  final TextEditingController _foodController = TextEditingController();
  final GeminiNutritionService _geminiService = GeminiNutritionService();
  final SupabaseNutritionService _supabaseService = SupabaseNutritionService();
  final UserGoalsService _goalsService = UserGoalsService();

  // Nutrition values
  double caloriesValue = 0;
  double caloriesLimit = 2500;
  double proteinValue = 0;
  double carbsValue = 0;
  double fatValue = 0;

  // Target values (in grams)
  double proteinTarget = 150;
  double carbsTarget = 250;
  double fatTarget = 70;

  // Food log items
  List<Map<String, dynamic>> foodLog = [];
  bool isLoading = false;
  bool isCalculating = false;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayData() async {
    setState(() => isLoading = true);

    try {
      // Load user goals first
      final goalsData = await _goalsService.getUserGoals();
      if (goalsData != null) {
        setState(() {
          caloriesLimit = (goalsData['calories_goal'] ?? 2500).toDouble();
          proteinTarget = (goalsData['protein_goal_g'] ?? 150).toDouble();
          carbsTarget = (goalsData['carbs_goal_g'] ?? 250).toDouble();
          fatTarget = (goalsData['fat_goal_g'] ?? 70).toDouble();
        });
      }

      // Load totals
      final totals = await _supabaseService.getTodayTotals();
      
      // Load meal logs
      final meals = await _supabaseService.getTodayMeals();

      setState(() {
        caloriesValue = (totals['calories'] ?? 0).toDouble();
        proteinValue = (totals['protein'] ?? 0).toDouble();
        carbsValue = (totals['carbs'] ?? 0).toDouble();
        fatValue = (totals['fat'] ?? 0).toDouble();
        foodLog = meals;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to load data');
    }
  }

  Future<void> _addMeal() async {
    if (_foodController.text.isEmpty) {
      _showErrorSnackBar('Please enter food name');
      return;
    }

    setState(() => isCalculating = true);

    try {
      // Call Gemini API
      final nutritionData = await _geminiService.getNutritionInfo(_foodController.text);

      if (nutritionData == null) {
        _showErrorSnackBar('Could not fetch nutrition data. Please try again.');
        setState(() => isCalculating = false);
        return;
      }

      // Save to database
      final success = await _supabaseService.logMeal(
        foodName: nutritionData.foodName,
        servingSize: nutritionData.servingSize,
        calories: nutritionData.calories,
        protein: nutritionData.protein,
        carbs: nutritionData.carbs,
        fat: nutritionData.fat,
        activityDate: DateTime.now(),
      );

      if (success) {
        // Update UI
        setState(() {
          caloriesValue += nutritionData.calories;
          proteinValue += nutritionData.protein;
          carbsValue += nutritionData.carbs;
          fatValue += nutritionData.fat;

          foodLog.insert(0, {
            'food_name': nutritionData.foodName,
            'serving_size': nutritionData.servingSize,
            'calories': nutritionData.calories,
            'protein_g': nutritionData.protein,
            'carbs_g': nutritionData.carbs,
            'fat_g': nutritionData.fat,
          });

          _foodController.clear();
          isCalculating = false;
        });

        _showSuccessSnackBar('Meal added successfully!');
      } else {
        setState(() => isCalculating = false);
        _showErrorSnackBar('Failed to save meal');
      }
    } catch (e) {
      print('Error adding meal: $e');
      setState(() => isCalculating = false);
      _showErrorSnackBar('An error occurred. Please try again.');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2647),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button with Stack
                      Stack(
                        children: [
                          Positioned(
                            top: 8,
                            left: 0,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Column(
                              children: [
                                Center(
                                  child: Text(
                                    'NUTRITION',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    "Today's Fuel",
                                    style: GoogleFonts.caveat(
                                      color: const Color(0xFFD4FF00),
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nutrition Cards Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionCard(
                              'Calories',
                              '${caloriesValue.toInt()} kcal',
                              caloriesValue / caloriesLimit,
                              const Color(0xFFE6D5FF),
                              const Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNutritionCard(
                              'Protein',
                              '${proteinValue.toInt()}g',
                              proteinValue / proteinTarget,
                              const Color(0xFFB8F4D3),
                              const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionCard(
                              'Carbs',
                              '${carbsValue.toInt()}g',
                              carbsValue / carbsTarget,
                              const Color(0xFFFEF3C7),
                              const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNutritionCard(
                              'Fat',
                              '${fatValue.toInt()}g',
                              fatValue / fatTarget,
                              const Color(0xFFFFCDB2),
                              const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Set new limits link
                      Center(
                        child: TextButton(
                          onPressed: _showSetLimitsDialog,
                          child: Text(
                            'Set new limits?',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Add Meal Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A52),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2D5F7E),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+ Add Meal',
                              style: GoogleFonts.roboto(
                                color: const Color(0xFF4ADE80),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _foodController,
                              style: GoogleFonts.roboto(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'e.g., Chicken 200g or 2 eggs',
                                hintStyle: GoogleFonts.roboto(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2D5F7E),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isCalculating ? null : _addMeal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4ADE80),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  disabledBackgroundColor: Colors.grey,
                                ),
                                child: isCalculating
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                        ),
                                      )
                                    : Text(
                                        'Calculate',
                                        style: GoogleFonts.roboto(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Food Log Section
                      Text(
                        'Food Log',
                        style: GoogleFonts.caveat(
                          color: const Color(0xFF4ADE80),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Food Log Items
                      if (foodLog.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No meals logged yet',
                              style: GoogleFonts.roboto(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ...foodLog.map((meal) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildFoodLogItem(
                                meal['food_name'],
                                meal['serving_size'],
                                (meal['calories'] as num).toInt(),
                                (meal['protein_g'] as num).toInt(),
                                (meal['carbs_g'] as num).toInt(),
                                (meal['fat_g'] as num).toInt(),
                              ),
                            )),
                      const SizedBox(height: 100),
                    ],
                  ),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                },
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white, size: 28),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionCard(
    String title,
    String value,
    double progress,
    Color bgColor,
    Color progressColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.roboto(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.black.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.roboto(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoodLogItem(
    String name,
    String servingSize,
    int calories,
    int protein,
    int carbs,
    int fat,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2D5F7E),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2D5F7E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Colors.white54,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  servingSize,
                  style: GoogleFonts.roboto(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildNutrientInfo(Icons.local_fire_department, '$calories kcal'),
                    const SizedBox(width: 16),
                    _buildNutrientInfo(Icons.fitness_center, 'P: ${protein}g'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildNutrientInfo(Icons.grain, 'C: ${carbs}g'),
                    const SizedBox(width: 16),
                    _buildNutrientInfo(Icons.water_drop, 'F: ${fat}g'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.roboto(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showSetLimitsDialog() {
    final TextEditingController caloriesController =
        TextEditingController(text: caloriesLimit.toInt().toString());
    final TextEditingController proteinController =
        TextEditingController(text: proteinTarget.toInt().toString());
    final TextEditingController carbsController =
        TextEditingController(text: carbsTarget.toInt().toString());
    final TextEditingController fatController =
        TextEditingController(text: fatTarget.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A52),
        title: Text(
          'Set New Limits',
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLimitField('Calories (kcal)', caloriesController),
              const SizedBox(height: 16),
              _buildLimitField('Protein (g)', proteinController),
              const SizedBox(height: 16),
              _buildLimitField('Carbs (g)', carbsController),
              const SizedBox(height: 16),
              _buildLimitField('Fat (g)', fatController),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCalories = double.tryParse(caloriesController.text) ?? caloriesLimit;
              final newProtein = double.tryParse(proteinController.text) ?? proteinTarget;
              final newCarbs = double.tryParse(carbsController.text) ?? carbsTarget;
              final newFat = double.tryParse(fatController.text) ?? fatTarget;

              // Save to database
              final success = await _goalsService.updateUserGoals(
                caloriesGoal: newCalories.toInt(),
                proteinGoal: newProtein.toInt(),
                carbsGoal: newCarbs.toInt(),
                fatGoal: newFat.toInt(),
              );

              if (success) {
                setState(() {
                  caloriesLimit = newCalories;
                  proteinTarget = newProtein;
                  carbsTarget = newCarbs;
                  fatTarget = newFat;
                });
                Navigator.pop(context);
                _showSuccessSnackBar('Goals updated successfully!');
              } else {
                _showErrorSnackBar('Failed to update goals');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80),
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: GoogleFonts.roboto(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4ADE80)),
        ),
      ),
    );
  }
}