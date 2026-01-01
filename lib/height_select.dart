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
      FixedExtentScrollController(initialItem: 2);
  final FixedExtentScrollController _inchesController =
      FixedExtentScrollController(initialItem: 9);

  int _selectedFeet = 5;
  int _selectedInches = 10;
  bool _isLoading = false;

  static const _bgColor = Color(0xFF0A2852);

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

  Future<void> _saveUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No user logged in');
      }

      // Save to user_fitness table
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

      // Navigate to home or next screen after successful save
      // Replace with your actual home screen navigation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Example: Navigate to home screen after 1 second
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const HomeScreen()),
      // );

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                  'What is your Height?',
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

                SizedBox(height: height * 0.119),

                // DUAL WHEEL AREA
                SizedBox(
                  height: height * 0.348,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // FEET WHEEL
                      _buildHeightWheel(
                        controller: _feetController,
                        width: width,
                        height: height,
                        itemCount: 5,
                        startValue: 3,
                        selectedValue: _selectedFeet,
                        unit: 'ft',
                        onChanged: (value) => setState(() => _selectedFeet = value),
                      ),

                      SizedBox(width: width * 0.097),

                      // INCHES WHEEL
                      _buildHeightWheel(
                        controller: _inchesController,
                        width: width,
                        height: height,
                        itemCount: 11,
                        startValue: 1,
                        selectedValue: _selectedInches,
                        unit: 'in',
                        onChanged: (value) => setState(() => _selectedInches = value),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: height * 0.140),

                // CONFIRM BUTTON
                Center(
                  child: SizedBox(
                    width: width * 0.436,
                    height: height * 0.050,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveUserProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        elevation: 3,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: width * 0.052,
                              height: width * 0.052,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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

  Widget _buildHeightWheel({
    required FixedExtentScrollController controller,
    required double width,
    required double height,
    required int itemCount,
    required int startValue,
    required int selectedValue,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: width * 0.388,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListWheelScrollView.useDelegate(
            controller: controller,
            physics: const FixedExtentScrollPhysics(),
            itemExtent: height * 0.076,
            perspective: 0.002,
            onSelectedItemChanged: (index) => onChanged(index + startValue),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, idx) {
                final value = idx + startValue;
                final bool isCenter = value == selectedValue;
                final diff = (value - selectedValue).abs();

                final double fontSize = isCenter
                    ? width * 0.097
                    : (diff == 1 ? width * 0.081 : width * 0.068);

                final double opacity = isCenter ? 1.0 : (diff == 1 ? 0.9 : 0.8);

                return Center(
                  child: Text(
                    '$value $unit',
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: isCenter ? FontWeight.w700 : FontWeight.w400,
                      color: Colors.white.withOpacity(opacity),
                      letterSpacing: 2.5,
                    ),
                  ),
                );
              },
            ),
          ),

          // Top line
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

          // Bottom line
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