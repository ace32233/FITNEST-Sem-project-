import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'weight_select.dart';

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
      home: const AgeSelectionScreen(),
    );
  }
}

class AgeSelectionScreen extends StatefulWidget {
  const AgeSelectionScreen({super.key});
  @override
  State<AgeSelectionScreen> createState() => _AgeSelectionScreenState();
}

class _AgeSelectionScreenState extends State<AgeSelectionScreen> {
  final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: 20);

  int _selectedAge = 21;

  @override
  void initState() {
    super.initState();
    _selectedAge = _controller.initialItem + 1;
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
          Positioned.fill(
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: height * 0.00786),

                Padding(
                  padding: EdgeInsets.only(left: width * 0.03406),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, size: width * 0.11528),
                      color: Colors.white,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),

                SizedBox(height: height * 0.00786),

                Text(
                  'What is your age?',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: width * 0.06288,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),

                SizedBox(height: height * 0.14148),

                SizedBox(
                  height: height * 0.34846,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ListWheelScrollView.useDelegate(
                        controller: _controller,
                        physics: const FixedExtentScrollPhysics(),
                        itemExtent: height * 0.08646,
                        perspective: 0.002,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedAge = index + 1;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 99,
                          builder: (context, idx) {
                            final age = idx + 1;
                            final bool isCenter = age == _selectedAge;
                            final diff = (age - _selectedAge).abs();

                            final double fontSize = isCenter
                                ? width * 0.09694
                                : (diff == 1 ? width * 0.08122 : width * 0.06812);

                            final double opacity =
                                isCenter ? 1.0 : (diff == 1 ? 0.9 : 0.8);

                            return Center(
                              child: Text(
                                '$age',
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

                      Positioned(
                        top: height * 0.34846 / 2 - height * 0.03275,
                        child: Container(
                          width: width * 0.24366,
                          height: height * 0.00524,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      Positioned(
                        top: height * 0.34846 / 2 + height * 0.0262,
                        child: Container(
                          width: width * 0.24366,
                          height: height * 0.00524,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: height * 0.17),

                Center(
                  child: SizedBox(
                    width: width * 0.38776,
                    height: height * 0.04978,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WeightSelectionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(width * 0.09694),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'Next',
                        style: GoogleFonts.poppins(
                          fontSize: width * 0.0524,
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

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    
    final startY = size.height * 0.59;
    path.moveTo(0, startY);
    
    final cp1X = size.width * 0.10;
    final cp1Y = size.height * 0.70;
    final cp2X = size.width * 0.25;
    final cp2Y = size.height * 0.71;
    final endX1 = size.width * 0.35;
    final endY1 = size.height * 0.695;
    
    path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, endX1, endY1);
    
    final cp3X = size.width * 0.45;
    final cp3Y = size.height * 0.68;
    final cp4X = size.width * 0.75;
    final cp4Y = size.height * 0.60;
    final endX2 = size.width * 0.89;
    final endY2 = size.height * 0.664;
    
    path.cubicTo(cp3X, cp3Y, cp4X, cp4Y, endX2, endY2);
    
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