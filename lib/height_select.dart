import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const HeightSelectionScreen(),
    );
  }
}

class HeightSelectionScreen extends StatefulWidget {
  const HeightSelectionScreen({super.key});
  @override
  State<HeightSelectionScreen> createState() => _HeightSelectionScreenState();
}

class _HeightSelectionScreenState extends State<HeightSelectionScreen> {
  final FixedExtentScrollController _feetController =
      FixedExtentScrollController(initialItem: 2); // Start at 5 ft
  final FixedExtentScrollController _inchesController =
      FixedExtentScrollController(initialItem: 9); // Start at 10 in

  int _selectedFeet = 5;
  int _selectedInches = 10;

  @override
  void initState() {
    super.initState();
    _selectedFeet = _feetController.initialItem + 3;
    _selectedInches = _inchesController.initialItem + 1;
  }

  @override
  void dispose() {
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: Stack(
        children: [
          // 🔹 BACKGROUND WITH WAVE
          Positioned.fill(
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),

          // 🔹 FOREGROUND CONTENT
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: height * 0.005),

                // Back Arrow
                Padding(
                  padding: EdgeInsets.only(left: width * 0.034),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, size: width * 0.115),
                      color: Colors.white,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),

                SizedBox(height: height * 0.008),

                // Title
                Text(
                  'What is your Height?',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: width * 0.063,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.normal,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: height * 0.007),

                Text(
                  'This helps us create your',
                  style: GoogleFonts.poppins(
                    fontSize: width * 0.037,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                    letterSpacing: 1.3,
                  ),
                ),
                Text(
                  'personalized plans',
                  style: GoogleFonts.poppins(
                    fontSize: width * 0.037,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                    letterSpacing: 1.3,
                  ),
                ),
                SizedBox(height: height * 0.119),

                // DUAL WHEEL AREA
                SizedBox(
                  height: height * 0.348,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // FEET WHEEL
                      SizedBox(
                        width: width * 0.388,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ListWheelScrollView.useDelegate(
                              controller: _feetController,
                              physics: const FixedExtentScrollPhysics(),
                              itemExtent: height * 0.076,
                              perspective: 0.002,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  _selectedFeet = index + 3;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 5, // 3-7 ft
                                builder: (context, idx) {
                                  final feet = idx + 3;
                                  final bool isCenter = feet == _selectedFeet;
                                  final diff = (feet - _selectedFeet).abs();

                                  final double fontSize =
                                      isCenter ? width * 0.097 : (diff == 1 ? width * 0.081 : width * 0.068);

                                  final double opacity =
                                      isCenter ? 1.0 : (diff == 1 ? 0.9 : 0.8);

                                  return Center(
                                    child: Text(
                                      '$feet ft', //value entry
                                      style: GoogleFonts.poppins(
                                        fontSize: fontSize,
                                        fontWeight: isCenter
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: Colors.white.withOpacity(opacity),
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // top line
                            Positioned(
                              top: height * 0.135,
                              child: Container(
                                width: width * 0.315,
                                height: height * 0.005,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),

                            // bottom line
                            Positioned(
                              top: height * 0.207,
                              child: Container(
                                width: width * 0.315,
                                height: height * 0.005,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: width * 0.097),

                      // INCHES WHEEL
                      SizedBox(
                        width: width * 0.388,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ListWheelScrollView.useDelegate(
                              controller: _inchesController,
                              physics: const FixedExtentScrollPhysics(),
                              itemExtent: height * 0.076,
                              perspective: 0.002,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  _selectedInches = index + 1;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 11, // 1-11 inches
                                builder: (context, idx) {
                                  final inches = idx + 1;
                                  final bool isCenter = inches == _selectedInches;
                                  final diff = (inches - _selectedInches).abs();

                                  final double fontSize =
                                      isCenter ? width * 0.097 : (diff == 1 ? width * 0.081 : width * 0.068);

                                  final double opacity =
                                      isCenter ? 1.0 : (diff == 1 ? 0.9 : 0.8);

                                  return Center(
                                    child: Text(
                                      '$inches in', //value entry
                                      style: GoogleFonts.poppins(
                                        fontSize: fontSize,
                                        fontWeight: isCenter
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: Colors.white.withOpacity(opacity),
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // top line
                            Positioned(
                              top: height * 0.135,
                              child: Container(
                                width: width * 0.315,
                                height: height * 0.005,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),

                            // bottom line
                            Positioned(
                              top: height * 0.207,
                              child: Container(
                                width: width * 0.315,
                                height: height * 0.005,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: height * 0.140),

                // BUTTON
                Center(
                  child: SizedBox(
                    width: width * 0.436,
                    height: height * 0.050,
                    child: ElevatedButton(
                      onPressed: () {
                        // You can access the selected values here
                        print('Selected: $_selectedFeet ft $_selectedInches in');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'Confirm',
                        style: GoogleFonts.poppins(
                          fontSize: width * 0.052,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔹 EXACT WAVE BACKGROUND PAINTER
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