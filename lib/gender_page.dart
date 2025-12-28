import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'age_select.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? selected;

  static const bgColor = Color(0xFF0A2852);

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for proportional scaling
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // WAVE BACKGROUND
          Positioned.fill(
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),

          // MAIN CONTENT
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  // TOP SPACING
                  SizedBox(height: screenHeight * 0.065),

                  // TITLE
                  Text(
                    'Tell us About Yourself',
                    style: GoogleFonts.poppins(
                      fontSize: screenWidth * 0.067,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      color: Colors.white,
                      letterSpacing: screenWidth * 0.004,
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.008),

                  Text(
                    'To give you a better experience',
                    style: GoogleFonts.poppins(
                      fontSize: screenWidth * 0.038,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      letterSpacing: screenWidth * 0.0033,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.08),
                  
                  // FLEXIBLE CENTER
                  Expanded(
                    child: Column(
                      children: [
                        buildGenderOption(
                          label: 'Male',
                          icon: Icons.male,
                          value: 'male',
                          size: screenWidth * 0.44,
                          iconSize: screenWidth * 0.28,
                          fontSize: screenWidth * 0.05,
                          letterSpacing: screenWidth * 0.0038,
                          borderWidth: screenWidth * 0.01,
                        ),

                        SizedBox(height: screenHeight * 0.09),

                        buildGenderOption(
                          label: 'Female',
                          icon: Icons.female,
                          value: 'female',
                          size: screenWidth * 0.44,
                          iconSize: screenWidth * 0.28,
                          fontSize: screenWidth * 0.05,
                          letterSpacing: screenWidth * 0.0038,
                          borderWidth: screenWidth * 0.01,
                        ),
                      ],
                    ),
                  ),

                  // NEXT BUTTON
                  Padding(
                    padding: EdgeInsets.only(bottom: screenHeight * 0.11),
                    child: SizedBox(
                      width: screenWidth * 0.41,
                      height: screenHeight * 0.053,
                      child: ElevatedButton(
                        onPressed: selected == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AgeSelectionScreen(),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(screenWidth * 0.1),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.w700,
                            letterSpacing: screenWidth * 0.0051,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- GENDER OPTION ----------
  Widget buildGenderOption({
    required String label,
    required IconData icon,
    required String value,
    required double size,
    required double iconSize,
    required double fontSize,
    required double letterSpacing,
    required double borderWidth,
  }) {
    final isSelected = selected == value;

    return GestureDetector(
      onTap: () => setState(() => selected = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: isSelected
              ? Border.all(color: Colors.amberAccent, width: borderWidth)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              weight: 100,
              color: Colors.black,
            ),
            SizedBox(height: size * 0.00001),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: letterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    
    // Starting point (left side)
    final startY = size.height * 0.59;
    path.moveTo(0, startY);
    
    // First curve - smooth transition to the valley
    final cp1X = size.width * 0.10;
    final cp1Y = size.height * 0.70;
    final cp2X = size.width * 0.25;
    final cp2Y = size.height * 0.71;
    final endX1 = size.width * 0.35;
    final endY1 = size.height * 0.695;
    
    path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, endX1, endY1);
    
    // Second curve - gentle rise to the peak
    final cp3X = size.width * 0.45;
    final cp3Y = size.height * 0.68;
    final cp4X = size.width * 0.75;
    final cp4Y = size.height * 0.60;
    final endX2 = size.width * 0.89;
    final endY2 = size.height * 0.664;
    
    path.cubicTo(cp3X, cp3Y, cp4X, cp4Y, endX2, endY2);
    
    // Final segment to right edge
    final cp5X = size.width * 0.90;
    final cp5Y = size.height * 0.6662;
    final endX3 = size.width;
    final endY3 = size.height * 0.715;
    
    path.quadraticBezierTo(cp5X, cp5Y, endX3, endY3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}