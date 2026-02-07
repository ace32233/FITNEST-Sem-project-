import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kGlassBorder = Color(0x33FFFFFF); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

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
  late final ValueNotifier<int> _feetNotifier;
  late final ValueNotifier<int> _inchesNotifier;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);

  late final FixedExtentScrollController _feetController;
  late final FixedExtentScrollController _inchesController;

  final supabase = Supabase.instance.client;

  static const int _initialFeetIndex = 2; // 5 ft (2 + 3)
  static const int _initialInchesIndex = 9; // 10 in (9 + 1)
  static const int _feetBaseOffset = 3;
  static const int _inchesBaseOffset = 1;

  @override
  void initState() {
    super.initState();
    _feetController = FixedExtentScrollController(initialItem: _initialFeetIndex);
    _inchesController = FixedExtentScrollController(initialItem: _initialInchesIndex);

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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
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
                'What is your Height?',
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

              SizedBox(height: layout.headerBottomSpacing),

              // 2. Wheels
              SizedBox(
                height: layout.wheelContainerHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shared Highlight Bar
                    Container(
                      height: layout.itemExtent,
                      width: size.width * 0.8,
                      decoration: BoxDecoration(
                        color: kAccentCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kAccentCyan.withOpacity(0.3)),
                      ),
                    ),
                    
                    // The Wheels
                    Row(
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
                  ],
                ),
              ),

              SizedBox(height: layout.footerSpacing),

              // 3. Confirm Button
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
                          backgroundColor: kAccentCyan,
                          foregroundColor: kDarkSlate,
                          disabledBackgroundColor: kCardSurface.withOpacity(0.5),
                          disabledForegroundColor: kTextGrey.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(layout.buttonRadius),
                          ),
                          elevation: 5,
                          shadowColor: kAccentCyan.withOpacity(0.4),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: kDarkSlate,
                                ),
                              )
                            : Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: layout.buttonFontSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
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
      ),
    );
  }
}

// --- SUB-WIDGETS ---

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
      child: ValueListenableBuilder<int>(
        valueListenable: notifier,
        builder: (context, selectedValue, _) {
          return ListWheelScrollView.useDelegate(
            controller: controller,
            physics: const FixedExtentScrollPhysics(),
            itemExtent: layout.itemExtent,
            perspective: 0.003,
            diameterRatio: 1.5,
            onSelectedItemChanged: (index) {
              notifier.value = index + baseOffset;
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, idx) {
                final value = idx + baseOffset;
                final bool isCenter = value == selectedValue;
                final double opacity = isCenter ? 1.0 : 0.4;
                final double fontSize = isCenter ? layout.fontSelected : layout.fontNeighbor;

                return Center(
                  child: Text(
                    '$value $labelSuffix',
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
      ),
    );
  }
}

// --- LOGIC & MATH ---

class _Layout {
  final double topSpacing;
  final double iconSize;
  final double titleFontSize;
  final double subtitleFontSize;
  final double headerBottomSpacing;
  final double wheelContainerHeight;
  final double wheelWidth;
  final double wheelGap;
  final double itemExtent;
  final double fontSelected;
  final double fontNeighbor;
  final double footerSpacing;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonRadius;
  final double buttonFontSize;

  _Layout(Size size)
      : topSpacing = size.height * 0.02,
        iconSize = 28,
        titleFontSize = size.width * 0.07,
        subtitleFontSize = size.width * 0.04,
        headerBottomSpacing = size.height * 0.05,
        wheelContainerHeight = size.height * 0.35,
        wheelWidth = size.width * 0.35,
        wheelGap = size.width * 0.05,
        itemExtent = 60,
        fontSelected = 36,
        fontNeighbor = 24,
        footerSpacing = size.height * 0.08,
        buttonWidth = size.width * 0.85,
        buttonHeight = 56,
        buttonRadius = 16,
        buttonFontSize = 18;
}