import 'package:flutter/material.dart';
import 'age_select.dart'; // Ensure this import is correct

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kGlassBorder = Color(0x33FFFFFF); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  // Use ValueNotifier for performance optimization
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
    final size = MediaQuery.sizeOf(context);
    // Encapsulate layout logic
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
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(height: layout.topPadding),

                // 1. Header Section
                _HeaderSection(layout: layout),

                SizedBox(height: layout.spacingAfterHeader),

                // 2. Dynamic Section: Gender Options
                Expanded(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _selectedGenderNotifier,
                    builder: (context, selectedGender, _) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GenderOption(
                            label: 'Male',
                            icon: Icons.male_rounded,
                            value: 'male',
                            isSelected: selectedGender == 'male',
                            onTap: () => _onGenderSelected('male'),
                            layout: layout,
                          ),
                          SizedBox(height: layout.spacingBetweenOptions),
                          _GenderOption(
                            label: 'Female',
                            icon: Icons.female_rounded,
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

                // 3. Next Button
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
                          child: Text(
                            'Next',
                            style: TextStyle(
                              fontSize: layout.buttonFontSize,
                              fontWeight: FontWeight.bold,
                              letterSpacing: layout.buttonLetterSpacing,
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
      ),
    );
  }
}

// --- SUB-WIDGETS ---

class _HeaderSection extends StatelessWidget {
  final _Layout layout;

  const _HeaderSection({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Tell us about yourself',
          style: TextStyle(
            fontSize: layout.titleFontSize,
            fontWeight: FontWeight.bold,
            color: kTextWhite,
            letterSpacing: layout.titleLetterSpacing,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: layout.titleSubtitleGap),
        Text(
          'To give you a better experience',
          style: TextStyle(
            fontSize: layout.subtitleFontSize,
            fontWeight: FontWeight.w400,
            color: kTextGrey,
            letterSpacing: layout.subtitleLetterSpacing,
          ),
          textAlign: TextAlign.center,
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
          color: isSelected ? kAccentCyan.withOpacity(0.15) : kCardSurface.withOpacity(0.4),
          border: Border.all(
            color: isSelected ? kAccentCyan : kGlassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kAccentCyan.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: layout.iconSize,
              color: isSelected ? kAccentCyan : kTextGrey,
            ),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kTextWhite : kTextGrey,
                fontSize: layout.optionFontSize,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                letterSpacing: layout.optionLetterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LOGIC & MATH ---

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
  final double bottomPadding;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonRadius;
  final double buttonFontSize;
  final double buttonLetterSpacing;

  _Layout(Size size)
      : topPadding = size.height * 0.05,
        titleFontSize = size.width * 0.07,
        titleLetterSpacing = 0.5,
        titleSubtitleGap = size.height * 0.01,
        subtitleFontSize = size.width * 0.04,
        subtitleLetterSpacing = 0.5,
        spacingAfterHeader = size.height * 0.05,
        spacingBetweenOptions = size.height * 0.05,
        optionSize = size.width * 0.42,
        iconSize = size.width * 0.18,
        optionFontSize = size.width * 0.05,
        optionLetterSpacing = 0.5,
        bottomPadding = size.height * 0.08,
        buttonWidth = size.width * 0.85,
        buttonHeight = 56,
        buttonRadius = 16,
        buttonFontSize = 18,
        buttonLetterSpacing = 1.0;
}