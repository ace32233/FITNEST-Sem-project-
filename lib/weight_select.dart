import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'height_select.dart';

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
      home: const WeightSelectionScreen(),
    );
  }
}

class WeightSelectionScreen extends StatefulWidget {
  const WeightSelectionScreen({super.key});
  @override
  State<WeightSelectionScreen> createState() => _WeightSelectionScreenState();
}

class _WeightSelectionScreenState extends State<WeightSelectionScreen> {
  final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: 70);

  int _selectedWeight = 71;

  @override
  void initState() {
    super.initState();
    _selectedWeight = _controller.initialItem + 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: Color(0xFF0A2852),
      body: Stack(
        children: [
          // 🔹 BACKGROUND WITH WAVE
          Positioned.fill(
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),

          //  FOREGROUND CONTENT
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
                  'What is your weight?',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: width * 0.063,
                    fontWeight: FontWeight.w700,
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
                SizedBox(height: height * 0.092),

                // WHEEL AREA
                SizedBox(
                  height: height * 0.348,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ListWheelScrollView.useDelegate(
                        controller: _controller,
                        physics: const FixedExtentScrollPhysics(),
                        itemExtent: height * 0.086,
                        perspective: 0.002,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedWeight = index + 1;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 99,
                          builder: (context, idx) {
                            final weight = idx + 1;
                            final bool isCenter = weight == _selectedWeight;
                            final diff = (weight - _selectedWeight).abs();

                            final double fontSize = isCenter
                                ? width * 0.097
                                : (diff == 1 ? width * 0.081 : width * 0.068);

                            final double opacity =
                                isCenter ? 1.0 : (diff == 1 ? 0.9 : 0.8);

                            return Center(
                              child: Text(
                                '$weight kg',
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
                          width: width * 0.364,
                          height: height * 0.005,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // bottom line
                      Positioned(
                        top: height * 0.210,
                        child: Container(
                          width: width * 0.364,
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

                SizedBox(height: height * 0.16),

                // BUTTON
                SizedBox(
                  width: width * 0.388,
                  height: height * 0.050,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HeightSelectionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      elevation: 3,
                    ),
                    child: Text(
                      'Next',
                      style: GoogleFonts.poppins(
                        fontSize: width * 0.052,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 2,
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

///  EXACT WAVE BACKGROUND PAINTER
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