import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';

class HeightSelectionScreen extends StatefulWidget {
  final String selectedGender;
  final int selectedAge;
  final int selectedWeight;

  const HeightSelectionScreen({
    super.key,
    required this.selectedGender,
    required this.selectedAge,
    required this.selectedWeight,
  });

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
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

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

  Future<void> _saveDataAndNavigate() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      // Save fitness data to Supabase
      await supabase.from('user_fitness').upsert({
        'id': user.id,
        'gender': widget.selectedGender,
        'age': widget.selectedAge,
        'weight_kg': widget.selectedWeight,
        'height_ft': _selectedFeet,
        'height_in': _selectedInches,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      // Navigate to home page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      _showError('Failed to save data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
          // BACKGROUND WITH WAVE
          const Positioned.fill(
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),

          // FOREGROUND CONTENT
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
                                      '$feet ft',
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
                                      '$inches in',
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
                      onPressed: _isLoading ? null : _saveDataAndNavigate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        elevation: 3,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Text(
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