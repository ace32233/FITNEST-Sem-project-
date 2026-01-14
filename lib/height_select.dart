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
  // Use ValueNotifiers to isolate state updates to specific widgets
  // preventing the entire screen from rebuilding during scrolling.
  late final ValueNotifier<int> _feetNotifier;
  late final ValueNotifier<int> _inchesNotifier;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);

  late final FixedExtentScrollController _feetController;
  late final FixedExtentScrollController _inchesController;

  final supabase = Supabase.instance.client;

  // Constants for initial values
  static const int _initialFeetIndex = 2; // 5 ft (2 + 3)
  static const int _initialInchesIndex = 9; // 10 in (9 + 1)
  static const int _feetBaseOffset = 3; // Starts at 3 ft
  static const int _inchesBaseOffset = 1; // Starts at 1 in

  @override
  void initState() {
    super.initState();
    _feetController = FixedExtentScrollController(initialItem: _initialFeetIndex);
    _inchesController = FixedExtentScrollController(initialItem: _initialInchesIndex);

    // Initialize notifiers with calculated starting values
    _feetNotifier = ValueNotifier<int>(_initialFeetIndex + _feetBaseOffset);
    _inchesNotifier = ValueNotifier<int>(_initialInchesIndex + _inchesBaseOffset);
  }

  @override
  void dispose() {
    _feetController.dispose();
    _inchesController.dispose();
    _feetNotifier.dispose();
    _inchesNotifier.dispose();
    _isLoadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _saveDataAndNavigate() async {
    _isLoadingNotifier.value = true;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      await supabase.from('user_fitness').upsert({
        'id': user.id,
        'gender': widget.selectedGender,
        'age': widget.selectedAge,
        'weight_kg': widget.selectedWeight,
        'height_ft': _feetNotifier.value,
        'height_in': _inchesNotifier.value,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      _showError('Failed to save data: $e');
    } finally {
      if (mounted) {
        _isLoadingNotifier.value = false;
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
    // Instantiate layout helper once per build
    final layout = _Layout(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: Stack(
        children: [
          // 1. Static Background: Extracted to const widget to prevent repainting
          const Positioned.fill(
            child: _WaveBackground(),
          ),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: layout.topSpacing),

                // 2. Header Section
                _Header(layout: layout),

                SizedBox(height: layout.headerBottomSpacing),

                // 3. Wheel Section: Contains both wheels
                SizedBox(
                  height: layout.wheelContainerHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeightWheel(
                        controller: _feetController,
                        notifier: _feetNotifier,
                        itemCount: 5,
                        baseOffset: _feetBaseOffset,
                        labelSuffix: 'ft',
                        layout: layout,
                      ),
                      SizedBox(width: layout.wheelGap),
                      _HeightWheel(
                        controller: _inchesController,
                        notifier: _inchesNotifier,
                        itemCount: 11,
                        baseOffset: _inchesBaseOffset,
                        labelSuffix: 'in',
                        layout: layout,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: layout.footerSpacing),

                // 4. Confirm Button
                Center(
                  child: SizedBox(
                    width: layout.buttonWidth,
                    height: layout.buttonHeight,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isLoadingNotifier,
                      builder: (context, isLoading, child) {
                        return ElevatedButton(
                          onPressed: isLoading ? null : _saveDataAndNavigate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            elevation: 3,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                )
                              : Text(
                                  'Confirm',
                                  style: GoogleFonts.poppins(
                                    fontSize: layout.buttonFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: 2,
                                  ),
                                ),
                        );
                      },
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

// --- Reusable Components ---

class _HeightWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final ValueNotifier<int> notifier;
  final int itemCount;
  final int baseOffset;
  final String labelSuffix;
  final _Layout layout;

  const _HeightWheel({
    required this.controller,
    required this.notifier,
    required this.itemCount,
    required this.baseOffset,
    required this.labelSuffix,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.wheelWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Scroll View wrapped in ValueListenableBuilder
          // Only this wheel rebuilds when its selection changes
          ValueListenableBuilder<int>(
            valueListenable: notifier,
            builder: (context, selectedValue, _) {
              return ListWheelScrollView.useDelegate(
                controller: controller,
                physics: const FixedExtentScrollPhysics(),
                itemExtent: layout.itemExtent,
                perspective: 0.002,
                onSelectedItemChanged: (index) {
                  notifier.value = index + baseOffset;
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: itemCount,
                  builder: (context, idx) {
                    final value = idx + baseOffset;
                    final bool isCenter = value == selectedValue;
                    final diff = (value - selectedValue).abs();

                    // Font size calculation extracted from original logic
                    final double fontSize = isCenter
                        ? layout.fontSelected
                        : (diff == 1
                            ? layout.fontNeighbor
                            : layout.fontFar);

                    final double opacity =
                        isCenter ? 1.0 : (diff == 1 ? 0.9 : 0.8);

                    return Center(
                      child: Text(
                        '$value $labelSuffix',
                        style: GoogleFonts.poppins(
                          fontSize: fontSize,
                          fontWeight:
                              isCenter ? FontWeight.w700 : FontWeight.w400,
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

          // Static selection lines
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
        SizedBox(height: layout.titleTopSpacing),
        Text(
          'What is your Height?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: layout.titleFontSize,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: layout.subtitleSpacing),
        Text(
          'This helps us create your',
          style: GoogleFonts.poppins(
            fontSize: layout.subtitleFontSize,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: Colors.white70,
            letterSpacing: 1.3,
          ),
        ),
        Text(
          'personalized plans',
          style: GoogleFonts.poppins(
            fontSize: layout.subtitleFontSize,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: Colors.white70,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class _WaveBackground extends StatelessWidget {
  const _WaveBackground();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: WavePainter());
  }
}

class WavePainter extends CustomPainter {
  const WavePainter();

  // Cache paint object to avoid allocation on every frame
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

/// Helper class to extract and pre-calculate responsive dimensions.
/// Removes "magic numbers" from the widget tree.
class _Layout {
  final double topSpacing;
  final double backButtonPadding;
  final double iconSize;
  final double titleTopSpacing;
  final double titleFontSize;
  final double subtitleSpacing;
  final double subtitleFontSize;
  final double headerBottomSpacing;
  final double wheelContainerHeight;
  final double wheelWidth;
  final double wheelGap;
  final double itemExtent;
  final double fontSelected;
  final double fontNeighbor;
  final double fontFar;
  final double lineWidth;
  final double lineHeight;
  final double lineTop1;
  final double lineTop2;
  final double footerSpacing;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonFontSize;

  _Layout(Size size)
      : topSpacing = size.height * 0.005,
        backButtonPadding = size.width * 0.034,
        iconSize = size.width * 0.115,
        titleTopSpacing = size.height * 0.008,
        titleFontSize = size.width * 0.063,
        subtitleSpacing = size.height * 0.007,
        subtitleFontSize = size.width * 0.037,
        headerBottomSpacing = size.height * 0.119,
        wheelContainerHeight = size.height * 0.348,
        wheelWidth = size.width * 0.388,
        wheelGap = size.width * 0.097,
        itemExtent = size.height * 0.076,
        fontSelected = size.width * 0.097,
        fontNeighbor = size.width * 0.081,
        fontFar = size.width * 0.068,
        lineWidth = size.width * 0.315,
        lineHeight = size.height * 0.005,
        // Calculate line positions relative to container
        lineTop1 = size.height * 0.135,
        lineTop2 = size.height * 0.207,
        footerSpacing = size.height * 0.140,
        buttonWidth = size.width * 0.436,
        buttonHeight = size.height * 0.050,
        buttonFontSize = size.width * 0.052;
}