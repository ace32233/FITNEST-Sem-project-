import 'package:flutter/material.dart';
import 'height_select.dart'; // Ensure this import is correct

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kGlassBorder = Color(0x33FFFFFF); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

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
  late final ValueNotifier<int> _selectedWeightNotifier;
  late final FixedExtentScrollController _controller;

  static const int _initialItemIndex = 70; // Represents 71kg (0-based index)

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _initialItemIndex);
    _selectedWeightNotifier = ValueNotifier<int>(_initialItemIndex + 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    _selectedWeightNotifier.dispose();
    super.dispose();
  }

  void _handleNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HeightSelectionScreen(
          selectedGender: widget.selectedGender,
          selectedAge: widget.selectedAge,
          selectedWeight: _selectedWeightNotifier.value,
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
                'What is your weight?',
                style: TextStyle(
                  color: kTextWhite,
                  fontSize: layout.titleFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us create your',
                style: TextStyle(
                  color: kTextGrey,
                  fontSize: layout.subtitleFontSize,
                ),
              ),
              Text(
                'personalized plans',
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
                    // Highlight Bar
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
                    _WeightPickerWheel(
                      controller: _controller,
                      layout: layout,
                      weightNotifier: _selectedWeightNotifier,
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

class _WeightPickerWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final _Layout layout;
  final ValueNotifier<int> weightNotifier;

  const _WeightPickerWheel({
    required this.controller,
    required this.layout,
    required this.weightNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: weightNotifier,
      builder: (context, selectedWeight, child) {
        return ListWheelScrollView.useDelegate(
          controller: controller,
          physics: const FixedExtentScrollPhysics(),
          itemExtent: layout.itemExtent,
          perspective: 0.003,
          diameterRatio: 1.5,
          onSelectedItemChanged: (index) {
            weightNotifier.value = index + 1;
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: 200, // Reasonable max weight
            builder: (context, idx) {
              final weight = idx + 1;
              final bool isCenter = weight == selectedWeight;
              final double opacity = isCenter ? 1.0 : 0.4;
              final double fontSize = isCenter ? layout.fontSelected : layout.fontNeighbor;

              return Center(
                child: Text(
                  '$weight kg',
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