


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LimitsPage extends StatefulWidget {
  const LimitsPage({Key? key}) : super(key: key);

  @override
  State<LimitsPage> createState() => _LimitsPageState();
}

class _LimitsPageState extends State<LimitsPage> {
  final TextEditingController calorieController = TextEditingController();
  final TextEditingController proteinController = TextEditingController();
  final TextEditingController carbsController = TextEditingController();
  final TextEditingController fatsController = TextEditingController();

  @override
  void dispose() {
    calorieController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatsController.dispose();
    super.dispose();
  }

  void _saveAndReturn() {
    final Map<String, String> dailyLimits = {
      'calories': calorieController.text,
      'protein': proteinController.text,
      'carbs': carbsController.text,
      'fats': fatsController.text,
    };
    Navigator.pop(context, dailyLimits);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing
    final horizontalPadding = screenWidth * 0.045;
    final boxHeight = screenHeight * 0.10;
    final spacing = screenHeight * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2D52),
      body: SafeArea(
        child: Stack(
          children: [
            // Back button positioned absolutely
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            // Main content
            Column(
              children: [
                // Title
                Padding(
                  padding: EdgeInsets.only(
                    top: screenHeight * 0.05,
                    bottom: screenHeight * 0.05,
                  ),
                  child: Text(
                    'Set Daily Limits',
                    style: GoogleFonts.poppins(
                      fontSize: screenWidth * 0.07,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Input fields
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      // Calories
                      _buildInputField(
                        label: 'Calorie(kcal)',
                        controller: calorieController,
                        backgroundColor: const Color(0xFFD4C5F9),
                        textColor: const Color(0xFF2D1B4E),
                        height: boxHeight,
                        screenWidth: screenWidth,
                      ),
                      
                      SizedBox(height: spacing),
                      
                      // Protein
                      _buildInputField(
                        label: 'Protein(gm)',
                        controller: proteinController,
                        backgroundColor: const Color(0xFF5ECC7B),
                        textColor: const Color(0xFF1B4D2E),
                        height: boxHeight,
                        screenWidth: screenWidth,
                      ),
                      
                      SizedBox(height: spacing),
                      
                      // Carbs
                      _buildInputField(
                        label: 'Carbs(gm)',
                        controller: carbsController,
                        backgroundColor: const Color(0xFFE8ED6C),
                        textColor: const Color(0xFF4D4A1B),
                        height: boxHeight,
                        screenWidth: screenWidth,
                      ),
                      
                      SizedBox(height: spacing),
                      
                      // Fats
                      _buildInputField(
                        label: 'Fats(gm)',
                        controller: fatsController,
                        backgroundColor: const Color(0xFFE86C52),
                        textColor: const Color(0xFF4D1F1B),
                        height: boxHeight,
                        screenWidth: screenWidth,
                      ),
                      
                      SizedBox(height: screenHeight * 0.10),
                      
                      // Save button
                      ElevatedButton(
                        onPressed: _saveAndReturn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F2D52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.08,
                            vertical: screenHeight * 0.010,
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.072,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required Color backgroundColor,
    required Color textColor,
    required double height,
    required double screenWidth,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white,
          width: 1.75,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.045),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child:              
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.063,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.8),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter Value',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: screenWidth * 0.035,
                    color: textColor.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: height * 0.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}