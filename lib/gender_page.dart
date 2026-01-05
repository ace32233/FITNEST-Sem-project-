import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'age_select.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? _selectedGender;

  static const _bgColor = Color(0xFF0A2852);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // WAVE BACKGROUND
          const Positioned.fill(
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
                  SizedBox(height: screenHeight * 0.065),

                  // TITLE
                  Text(
                    'Tell us About Yourself',
                    style: GoogleFonts.poppins(
                      fontSize: screenWidth * 0.067,
                      fontWeight: FontWeight.w700,
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
                  
                  // GENDER OPTIONS
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _GenderOption(
                          label: 'Male',
                          icon: Icons.male,
                          value: 'male',
                          isSelected: _selectedGender == 'male',
                          onTap: () => setState(() => _selectedGender = 'male'),
                          size: screenWidth * 0.44,
                          iconSize: screenWidth * 0.28,
                          fontSize: screenWidth * 0.05,
                          letterSpacing: screenWidth * 0.0038,
                          borderWidth: screenWidth * 0.01,
                        ),

                        SizedBox(height: screenHeight * 0.09),

                        _GenderOption(
                          label: 'Female',
                          icon: Icons.female,
                          value: 'female',
                          isSelected: _selectedGender == 'female',
                          onTap: () => setState(() => _selectedGender = 'female'),
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
                        onPressed: _selectedGender == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgeSelectionScreen(
                                      selectedGender: _selectedGender!,
                                    ),
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
}

// Extracted as a separate stateless widget for better performance
class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final double fontSize;
  final double letterSpacing;
  final double borderWidth;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.isSelected,
    required this.onTap,
    required this.size,
    required this.iconSize,
    required this.fontSize,
    required this.letterSpacing,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
  const WavePainter();

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
    path.cubicTo(
      size.width * 0.10, size.height * 0.70,
      size.width * 0.25, size.height * 0.71,
      size.width * 0.35, size.height * 0.695,
    );
    
    // Second curve - gentle rise to the peak
    path.cubicTo(
      size.width * 0.45, size.height * 0.68,
      size.width * 0.75, size.height * 0.60,
      size.width * 0.89, size.height * 0.664,
    );
    
    // Final segment to right edge
    path.quadraticBezierTo(
      size.width * 0.90, size.height * 0.6662,
      size.width, size.height * 0.715,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}