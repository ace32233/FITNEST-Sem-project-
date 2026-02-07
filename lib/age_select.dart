import 'package:flutter/material.dart';
import 'weight_select.dart'; // Ensure this import is correct

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kGlassBorder = Color(0x33FFFFFF); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

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
  late final ValueNotifier<int> _selectedAgeNotifier;
  late final FixedExtentScrollController _controller;

  static const int _initialItemIndex = 20;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _initialItemIndex);
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
    final size = MediaQuery.sizeOf(context);
    final layout = _Layout(size);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kDarkSlate, kDarkTeal], // Glossy Background
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: kTextWhite, size: layout.iconSize),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(height: layout.topSpacing),

              // 1. Header
              Text(
                'How old are you?',
                style: TextStyle(
                  color: kTextWhite,
                  fontSize: layout.titleFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us tailor your plan',
                style: TextStyle(
                  color: kTextGrey,
                  fontSize: layout.subtitleFontSize,
                ),
              ),

              SizedBox(height: layout.titleSpacing),

              // 2. Wheel Picker
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Highlight Bar (Behind the numbers)
                    Container(
                      height: layout.itemExtent,
                      width: size.width * 0.5,
                      decoration: BoxDecoration(
                        color: kAccentCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kAccentCyan.withOpacity(0.3)),
                      ),
                    ),
                    
                    // The Wheel
                    _AgePickerWheel(
                      controller: _controller,
                      layout: layout,
                      ageNotifier: _selectedAgeNotifier,
                    ),
                  ],
                ),
              ),

              SizedBox(height: layout.bottomSpacing),

              // 3. Next Button
              Padding(
                padding: EdgeInsets.only(bottom: layout.bottomPadding),
                child: SizedBox(
                  width: layout.buttonWidth,
                  height: layout.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentCyan,
                      foregroundColor: kDarkSlate,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(layout.buttonRadius),
                      ),
                      elevation: 5,
                      shadowColor: kAccentCyan.withOpacity(0.4),
                    ),
                    child: Text(
                      'Next',
                      style: TextStyle(
                        fontSize: layout.buttonFontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Sub-Widgets ---

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
    return ValueListenableBuilder<int>(
      valueListenable: ageNotifier,
      builder: (context, selectedAge, child) {
        return ListWheelScrollView.useDelegate(
          controller: controller,
          physics: const FixedExtentScrollPhysics(),
          itemExtent: layout.itemExtent,
          perspective: 0.003,
          diameterRatio: 1.5,
          onSelectedItemChanged: (index) {
            ageNotifier.value = index + 1;
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: 99,
            builder: (context, idx) {
              final age = idx + 1;
              final bool isCenter = age == selectedAge;
              final double opacity = isCenter ? 1.0 : 0.4;
              final double fontSize = isCenter ? layout.fontSelected : layout.fontNeighbor;

              return Center(
                child: Text(
                  '$age',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
                    color: isCenter ? kAccentCyan : kTextGrey.withOpacity(opacity),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// --- Layout Helper ---

class _Layout {
  final double topSpacing;
  final double iconSize;
  final double titleFontSize;
  final double subtitleFontSize;
  final double titleSpacing;
  final double itemExtent;
  final double fontSelected;
  final double fontNeighbor;
  final double bottomSpacing;
  final double bottomPadding;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonRadius;
  final double buttonFontSize;

  _Layout(Size size)
      : topSpacing = size.height * 0.02,
        iconSize = 28,
        titleFontSize = size.width * 0.07,
        subtitleFontSize = size.width * 0.04,
        titleSpacing = size.height * 0.05,
        itemExtent = 60,
        fontSelected = 42,
        fontNeighbor = 28,
        bottomSpacing = size.height * 0.05,
        bottomPadding = size.height * 0.05,
        buttonWidth = size.width * 0.85,
        buttonHeight = 56,
        buttonRadius = 16,
        buttonFontSize = 18;
}