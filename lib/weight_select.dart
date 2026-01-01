import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'height_select.dart';

class WeightSelectionScreen extends StatefulWidget {
  final String selectedGender;
  final int selectedAge;

  const WeightSelectionScreen({
    super.key,
    required this.selectedGender,
    required this.selectedAge,
  });

  @override
  State<WeightSelectionScreen> createState() => _WeightSelectionScreenState();
}

class _WeightSelectionScreenState extends State<WeightSelectionScreen> {
  final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: 70);

  int _selectedWeight = 71;

  static const _bgColor = Color(0xFF0A2852);

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
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: height * 0.005),

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

                SizedBox(
                  width: width * 0.388,
                  height: height * 0.050,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HeightSelectionScreen(
                            selectedGender: widget.selectedGender,
                            selectedAge: widget.selectedAge,
                            selectedWeight: _selectedWeight,
                          ),
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

class WavePainter extends CustomPainter {
  const WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();

    final startY = size.height * 0.59;
    path.moveTo(0, startY);

    path.cubicTo(
      size.width * 0.10, size.height * 0.70,
      size.width * 0.25, size.height * 0.71,
      size.width * 0.35, size.height * 0.695,
    );

    path.cubicTo(
      size.width * 0.45, size.height * 0.68,
      size.width * 0.75, size.height * 0.60,
      size.width * 0.89, size.height * 0.664,
    );

    path.quadraticBezierTo(
      size.width * 0.90, size.height * 0.6662,
      size.width, size.height * 0.715,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}