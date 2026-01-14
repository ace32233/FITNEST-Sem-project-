import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'weight_select.dart';

class AgeSelectionScreen extends StatefulWidget {
  final String selectedGender;

  const AgeSelectionScreen({
    super.key,
    required this.selectedGender,
  });

  @override
  State<AgeSelectionScreen> createState() => _AgeSelectionScreenState();
}

class _AgeSelectionScreenState extends State<AgeSelectionScreen> {
  // Use ValueNotifier to isolate rebuilds to only the wheel widget
  // instead of rebuilding the entire screen via setState.
  late final ValueNotifier<int> _selectedAgeNotifier;
  late final FixedExtentScrollController _controller;

  static const int _initialItemIndex = 20;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _initialItemIndex);
    // Initialize age based on initial scroll index (index + 1)
    _selectedAgeNotifier = ValueNotifier<int>(_initialItemIndex + 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    _selectedAgeNotifier.dispose();
    super.dispose();
  }

  void _handleNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightSelectionScreen(
          selectedGender: widget.selectedGender,
          selectedAge: _selectedAgeNotifier.value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Encapsulate responsive logic in a helper class to clean up the build method
    final layout = _Layout(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: Stack(
        children: [
          // 1. Extracted to const widget to prevent repainting on scroll
          const Positioned.fill(
            child: _WaveBackground(),
          ),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: layout.topSpacing),

                // 2. Extracted header components
                _Header(layout: layout),

                SizedBox(height: layout.titleSpacing),

                // 3. Wheel logic isolated in specific widget
                // Only this widget rebuilds when the wheel scrolls
                _AgePickerWheel(
                  controller: _controller,
                  layout: layout,
                  ageNotifier: _selectedAgeNotifier,
                ),

                SizedBox(height: layout.bottomSpacing),

                // 4. Next button remains static, reads value on press
                Center(
                  child: SizedBox(
                    width: layout.buttonWidth,
                    height: layout.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(layout.buttonRadius),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'Next',
                        style: GoogleFonts.poppins(
                          fontSize: layout.buttonFontSize,
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

// --- Sub-Widgets & Helpers ---

class _Header extends StatelessWidget {
  final _Layout layout;

  const _Header({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(left: layout.backButtonPadding),
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: layout.iconSize),
              color: Colors.white,
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
        SizedBox(height: layout.topSpacing),
        Text(
          'What is your age?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: layout.titleFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _AgePickerWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final _Layout layout;
  final ValueNotifier<int> ageNotifier;

  const _AgePickerWheel({
    required this.controller,
    required this.layout,
    required this.ageNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.wheelContainerHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Use ValueListenableBuilder to rebuild ONLY the list when age changes
          ValueListenableBuilder<int>(
            valueListenable: ageNotifier,
            builder: (context, selectedAge, child) {
              return ListWheelScrollView.useDelegate(
                controller: controller,
                physics: const FixedExtentScrollPhysics(),
                itemExtent: layout.itemExtent,
                perspective: 0.002,
                onSelectedItemChanged: (index) {
                  // Update the notifier instead of calling setState on the whole screen
                  ageNotifier.value = index + 1;
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 99,
                  builder: (context, idx) {
                    final age = idx + 1;
                    final bool isCenter = age == selectedAge;
                    final int diff = (age - selectedAge).abs();

                    // Optimized calculation logic
                    final double fontSize = isCenter
                        ? layout.fontSelected
                        : (diff == 1
                            ? layout.fontNeighbor
                            : layout.fontFar);

                    final double opacity =
                        isCenter ? 1.0 : (diff == 1 ? 0.9 : 0.8);

                    return Center(
                      child: Text(
                        '$age',
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
              );
            },
          ),
          // Selection Lines (Static)
          Positioned(
            top: layout.lineTop1,
            child: _SelectionLine(layout: layout),
          ),
          Positioned(
            top: layout.lineTop2,
            child: _SelectionLine(layout: layout),
          ),
        ],
      ),
    );
  }
}

class _SelectionLine extends StatelessWidget {
  final _Layout layout;

  const _SelectionLine({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: layout.lineWidth,
      height: layout.lineHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _WaveBackground extends StatelessWidget {
  const _WaveBackground();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: WavePainter(),
    );
  }
}

// --- Logic & Math ---

/// Helper class to calculate and hold responsive dimensions.
/// Extracts magic numbers from the build method.
class _Layout {
  final double topSpacing;
  final double backButtonPadding;
  final double iconSize;
  final double titleFontSize;
  final double titleSpacing;
  final double wheelContainerHeight;
  final double itemExtent;
  final double fontSelected;
  final double fontNeighbor;
  final double fontFar;
  final double lineWidth;
  final double lineHeight;
  final double lineTop1;
  final double lineTop2;
  final double bottomSpacing;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonRadius;
  final double buttonFontSize;

  _Layout(Size size)
      : topSpacing = size.height * 0.00786,
        backButtonPadding = size.width * 0.03406,
        iconSize = size.width * 0.11528,
        titleFontSize = size.width * 0.06288,
        titleSpacing = size.height * 0.14148,
        wheelContainerHeight = size.height * 0.34846,
        itemExtent = size.height * 0.08646,
        fontSelected = size.width * 0.09694,
        fontNeighbor = size.width * 0.08122,
        fontFar = size.width * 0.06812,
        lineWidth = size.width * 0.24366,
        lineHeight = size.height * 0.00524,
        lineTop1 = (size.height * 0.34846 / 2) - (size.height * 0.03275),
        lineTop2 = (size.height * 0.34846 / 2) + (size.height * 0.0262),
        bottomSpacing = size.height * 0.17,
        buttonWidth = size.width * 0.38776,
        buttonHeight = size.height * 0.04978,
        buttonRadius = size.width * 0.09694,
        buttonFontSize = size.width * 0.0524;
}

class WavePainter extends CustomPainter {
  const WavePainter();

  // Cache the paint object to avoid recreating it every frame
  static final Paint _paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();

    final startY = size.height * 0.59;
    path.moveTo(0, startY);

    path.cubicTo(
      size.width * 0.10,
      size.height * 0.70,
      size.width * 0.25,
      size.height * 0.71,
      size.width * 0.35,
      size.height * 0.695,
    );

    path.cubicTo(
      size.width * 0.45,
      size.height * 0.68,
      size.width * 0.75,
      size.height * 0.60,
      size.width * 0.89,
      size.height * 0.664,
    );

    path.quadraticBezierTo(
      size.width * 0.90,
      size.height * 0.6662,
      size.width,
      size.height * 0.715,
    );

    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}