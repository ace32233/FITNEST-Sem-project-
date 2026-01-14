import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'age_select.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  // Optimization: Use ValueNotifier to isolate state changes.
  // This prevents the entire Scaffold (background, titles) from rebuilding on tap.
  final ValueNotifier<String?> _selectedGenderNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _selectedGenderNotifier.dispose();
    super.dispose();
  }

  void _onGenderSelected(String gender) {
    _selectedGenderNotifier.value = gender;
  }

  void _handleNext(BuildContext context) {
    final gender = _selectedGenderNotifier.value;
    if (gender != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgeSelectionScreen(selectedGender: gender),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Encapsulate responsive logic to clean up the build method and avoid repetitive calculations.
    final layout = _Layout(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: Stack(
        children: [
          // 1. Static Background: Never rebuilds
          const Positioned.fill(
            child: CustomPaint(
              painter: WavePainter(),
            ),
          ),

          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  SizedBox(height: layout.topPadding),

                  // 2. Extracted Static Header
                  _HeaderSection(layout: layout),

                  SizedBox(height: layout.spacingAfterHeader),

                  // 3. Dynamic Section: Gender Options
                  // Uses ValueListenableBuilder to only rebuild the buttons when selection changes
                  Expanded(
                    child: ValueListenableBuilder<String?>(
                      valueListenable: _selectedGenderNotifier,
                      builder: (context, selectedGender, _) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _GenderOption(
                              label: 'Male',
                              icon: Icons.male,
                              value: 'male',
                              isSelected: selectedGender == 'male',
                              onTap: () => _onGenderSelected('male'),
                              layout: layout,
                            ),
                            SizedBox(height: layout.spacingBetweenOptions),
                            _GenderOption(
                              label: 'Female',
                              icon: Icons.female,
                              value: 'female',
                              isSelected: selectedGender == 'female',
                              onTap: () => _onGenderSelected('female'),
                              layout: layout,
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // 4. Dynamic Section: Next Button
                  // Separate listener ensures we only rebuild the button's enabled state
                  Padding(
                    padding: EdgeInsets.only(bottom: layout.bottomPadding),
                    child: ValueListenableBuilder<String?>(
                      valueListenable: _selectedGenderNotifier,
                      builder: (context, selectedGender, _) {
                        return SizedBox(
                          width: layout.buttonWidth,
                          height: layout.buttonHeight,
                          child: ElevatedButton(
                            onPressed: selectedGender == null
                                ? null
                                : () => _handleNext(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(layout.buttonRadius),
                              ),
                              elevation: 3,
                            ),
                            child: Text(
                              'Next',
                              style: GoogleFonts.poppins(
                                fontSize: layout.buttonFontSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: layout.buttonLetterSpacing,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
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

// --- Sub-Widgets & Helpers ---

class _HeaderSection extends StatelessWidget {
  final _Layout layout;

  const _HeaderSection({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Tell us About Yourself',
          style: GoogleFonts.poppins(
            fontSize: layout.titleFontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: layout.titleLetterSpacing,
          ),
        ),
        SizedBox(height: layout.titleSubtitleGap),
        Text(
          'To give you a better experience',
          style: GoogleFonts.poppins(
            fontSize: layout.subtitleFontSize,
            fontWeight: FontWeight.w400,
            color: Colors.white70,
            letterSpacing: layout.subtitleLetterSpacing,
          ),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;
  final _Layout layout;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.isSelected,
    required this.onTap,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: layout.optionSize,
        width: layout.optionSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: isSelected
              ? Border.all(
                  color: Colors.amberAccent, width: layout.optionBorderWidth)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: layout.iconSize,
              weight: 100,
              color: Colors.black,
            ),
            // Tiny vertical adjustment kept from original logic
            SizedBox(height: layout.optionSize * 0.00001),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: layout.optionFontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: layout.optionLetterSpacing,
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

  // Optimization: Cache the Paint object to avoid recreating it every frame.
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

// --- Logic & Math ---

/// Helper class to centralized all responsive calculations.
/// Extracts "Magic Numbers" from the widget tree for readability and efficiency.
class _Layout {
  final double topPadding;
  final double titleFontSize;
  final double titleLetterSpacing;
  final double titleSubtitleGap;
  final double subtitleFontSize;
  final double subtitleLetterSpacing;
  final double spacingAfterHeader;
  final double spacingBetweenOptions;
  final double optionSize;
  final double iconSize;
  final double optionFontSize;
  final double optionLetterSpacing;
  final double optionBorderWidth;
  final double bottomPadding;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonRadius;
  final double buttonFontSize;
  final double buttonLetterSpacing;

  _Layout(Size size)
      : topPadding = size.height * 0.065,
        titleFontSize = size.width * 0.067,
        titleLetterSpacing = size.width * 0.004,
        titleSubtitleGap = size.height * 0.008,
        subtitleFontSize = size.width * 0.038,
        subtitleLetterSpacing = size.width * 0.0033,
        spacingAfterHeader = size.height * 0.08,
        spacingBetweenOptions = size.height * 0.09,
        optionSize = size.width * 0.44,
        iconSize = size.width * 0.28,
        optionFontSize = size.width * 0.05,
        optionLetterSpacing = size.width * 0.0038,
        optionBorderWidth = size.width * 0.01,
        bottomPadding = size.height * 0.11,
        buttonWidth = size.width * 0.41,
        buttonHeight = size.height * 0.053,
        buttonRadius = size.width * 0.1,
        buttonFontSize = size.width * 0.056,
        buttonLetterSpacing = size.width * 0.0051;
}