import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38);
const Color kDarkSlate = Color(0xFF0F172A);
const Color kCardSurface = Color(0xFF1E293B);
const Color kGlassBorder = Color(0x33FFFFFF);
const Color kGlassBase = Color(0x1AFFFFFF);
const Color kAccentCyan = Color(0xFF22D3EE);
const Color kAccentBlue = Color(0xFF3B82F6);
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;

  // Controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Focus Nodes
  final FocusNode _ageFocus = FocusNode();
  final FocusNode _heightFocus = FocusNode();
  final FocusNode _weightFocus = FocusNode();

  String _gender = 'Male';
  String _email = 'Loading...';
  double _bmi = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    // Save data only when focus is lost to prevent keyboard dismissal while typing
    _ageFocus.addListener(() {
      if (!_ageFocus.hasFocus) _saveProfile();
    });
    _heightFocus.addListener(() {
      if (!_heightFocus.hasFocus) _saveProfile();
    });
    _weightFocus.addListener(() {
      if (!_weightFocus.hasFocus) _saveProfile();
    });
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageFocus.dispose();
    _heightFocus.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  // --- Supabase ↔ UI mapping helpers (no UI changes) ---
  String _genderUiFromDb(String? db) {
    switch ((db ?? '').toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      default:
        return 'Male';
    }
  }

  String _genderDbFromUi(String ui) {
    switch (ui.toLowerCase()) {
      case 'male':
        return 'male';
      case 'female':
        return 'female';
      case 'other':
        return 'other';
      default:
        return 'male';
    }
  }

  /// UI uses centimeters. DB stores height as feet + inches (user_fitness.height_ft/height_in).
  Map<String, int> _cmToFeetIn(double cm) {
    if (cm <= 0) return {'ft': 0, 'in': 0};
    final totalIn = cm / 2.54;
    int ft = totalIn ~/ 12;
    int inch = (totalIn - (ft * 12)).round();
    if (inch == 12) {
      ft += 1;
      inch = 0;
    }
    inch = inch.clamp(0, 11).toInt();
    return {'ft': ft, 'in': inch};
  }

  double _feetInToCm(int ft, int inch) {
    final totalIn = (ft * 12) + inch;
    return totalIn * 2.54;
  }

  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;

    // Always show email quickly (UI behavior unchanged)
    setState(() {
      _email = user?.email ?? 'No Email';
    });

    // Local fallback (kept to avoid UI/UX changes or empty fields while offline)
    final prefs = await SharedPreferences.getInstance();
    _ageController.text = prefs.getString('profile_age') ?? '25';
    _heightController.text = prefs.getString('profile_height') ?? '175';
    _weightController.text = prefs.getString('profile_weight') ?? '70';
    _gender = prefs.getString('profile_gender') ?? 'Male';
    _calculateBMI();

    if (user == null) return;

    try {
      // Pull latest from Supabase (user_fitness)
      final fitness = await _supabase
          .from('user_fitness')
          .select('gender, age, weight_kg, height_ft, height_in')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (fitness != null) {
        final int age =
            (fitness['age'] as num?)?.toInt() ?? int.tryParse(_ageController.text) ?? 25;
        final double weightKg = (fitness['weight_kg'] as num?)?.toDouble() ??
            double.tryParse(_weightController.text) ??
            70;
        final int htFt = (fitness['height_ft'] as num?)?.toInt() ?? 0;
        final int htIn = (fitness['height_in'] as num?)?.toInt() ?? 0;
        final double heightCm = (htFt > 0 || htIn > 0)
            ? _feetInToCm(htFt, htIn)
            : (double.tryParse(_heightController.text) ?? 175);

        setState(() {
          _ageController.text = age.toString();
          _weightController.text = weightKg.toStringAsFixed(0);
          _heightController.text = heightCm.toStringAsFixed(0);
          _gender = _genderUiFromDb(fitness['gender'] as String?);
          _calculateBMI();
        });

        // Keep local cache in sync (non-UI)
        await prefs.setString('profile_age', _ageController.text);
        await prefs.setString('profile_height', _heightController.text);
        await prefs.setString('profile_weight', _weightController.text);
        await prefs.setString('profile_gender', _gender);
      } else {
        // If row doesn't exist yet, create it using current UI values (silent, no UI change)
        await _saveProfile();
      }
    } catch (e) {
      // If Supabase fetch fails, we keep the local values (no UI disruption)
      debugPrint('Profile load error: $e');
    }
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // Always keep local cache (behavior similar to before)
    await prefs.setString('profile_age', _ageController.text);
    await prefs.setString('profile_height', _heightController.text);
    await prefs.setString('profile_weight', _weightController.text);
    await prefs.setString('profile_gender', _gender);

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final int age = int.tryParse(_ageController.text.trim()) ?? 25;
    final double weightKg = double.tryParse(_weightController.text.trim()) ?? 70;
    final double heightCm = double.tryParse(_heightController.text.trim()) ?? 175;

    final heightParts = _cmToFeetIn(heightCm);

    try {
      await _supabase.from('user_fitness').upsert({
        'id': user.id,
        'gender': _genderDbFromUi(_gender),
        'age': age,
        'weight_kg': weightKg,
        'height_ft': heightParts['ft'],
        'height_in': heightParts['in'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Optional: ensure profiles row exists (safe upsert, does not affect UI)
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email ?? _email,
        'full_name': (user.userMetadata?['full_name'] as String?) ?? 'User',
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Profile save error: $e');
    }
  }

  void _calculateBMI() {
    double height = double.tryParse(_heightController.text) ?? 0;
    double weight = double.tryParse(_weightController.text) ?? 0;

    if (height > 0 && weight > 0) {
      double heightM = height / 100;
      setState(() {
        _bmi = weight / (heightM * heightM);
      });
    }
  }

  // --- Password Change Logic (With Backend Integration) ---
  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: kCardSurface.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: kGlassBorder),
            ),
            title: const Text("Change Password", style: TextStyle(color: kTextWhite)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Old Password
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: kTextWhite),
                  decoration: InputDecoration(
                    labelText: "Old Password",
                    labelStyle: TextStyle(color: kTextGrey.withOpacity(0.5)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: kGlassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: kAccentCyan),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // New Password
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: kTextWhite),
                  decoration: InputDecoration(
                    labelText: "New Password",
                    labelStyle: TextStyle(color: kTextGrey.withOpacity(0.5)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: kGlassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: kAccentCyan),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator(
                      color: kAccentCyan,
                      backgroundColor: kCardSurface,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: kTextGrey)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (oldPasswordController.text.isEmpty ||
                            newPasswordController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Password must be at least 6 characters.")),
                          );
                          return;
                        }

                        setState(() => isLoading = true);

                        try {
                          final userEmail = _supabase.auth.currentUser?.email;
                          if (userEmail == null) throw "User not found";

                          // 1. Verify Old Password (by re-authenticating)
                          await _supabase.auth.signInWithPassword(
                            email: userEmail,
                            password: oldPasswordController.text,
                          );

                          // 2. Update to New Password
                          await _supabase.auth.updateUser(
                            UserAttributes(password: newPasswordController.text),
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.green,
                                content: Text("Password changed successfully!"),
                              ),
                            );
                          }
                        } on AuthException catch (e) {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: Colors.red, content: Text(e.message)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: Colors.red, content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentCyan,
                  foregroundColor: kDarkSlate,
                ),
                child: const Text("Update"),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------
  // PRODUCTION LOGOUT (CONFIRMATION)
  // -------------------------------
  Future<void> _confirmAndLogout() async {
    // Keep UX stable: close keyboard before dialog
    FocusScope.of(context).unfocus();

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: kCardSurface.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kGlassBorder),
          ),
          title: const Text("Confirm Logout", style: TextStyle(color: kTextWhite)),
          content: const Text(
            "Are you sure you want to log out?",
            style: TextStyle(color: kTextGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel", style: TextStyle(color: kTextGrey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: kDarkSlate,
              ),
              child: const Text("Log Out"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    await _logout();
  }

  Future<void> _logout() async {
    try {
      // 1) Supabase sign out (invalidate session)
      await _supabase.auth.signOut();

      // 2) Clear local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;

      // 3) Navigate to login page (remove entire back stack)
      // IMPORTANT: Ensure your MaterialApp has route '/login' mapped to login_page.dart
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("Logout failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // Saves data due to focus listeners
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 120),
          child: Column(
            children: [
              // --- HEADER SECTION (DEFAULT ICON ONLY) ---
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kCardSurface,
                  border: Border.all(color: kAccentCyan.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentCyan.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, size: 50, color: kTextGrey),
              ),
              const SizedBox(height: 16),
              Text(
                _email,
                style: const TextStyle(
                  color: kTextWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),

              // --- STATS GRID ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Age Input
                  Expanded(
                    child: _buildGlossyInput(
                      "Age",
                      _ageController,
                      "yrs",
                      _ageFocus,
                      (val) => _calculateBMI(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Gender Dropdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Gender",
                            style: TextStyle(color: kTextGrey.withOpacity(0.8), fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          height: 56, // Matches TextField height
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: kCardSurface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kGlassBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _gender,
                              isExpanded: true,
                              dropdownColor: kCardSurface,
                              style: const TextStyle(
                                color: kTextWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kAccentCyan),
                              items: ['Male', 'Female', 'Other'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() => _gender = newValue!);
                                _saveProfile();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildGlossyInput(
                      "Height",
                      _heightController,
                      "cm",
                      _heightFocus,
                      (val) => _calculateBMI(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildGlossyInput(
                      "Weight",
                      _weightController,
                      "kg",
                      _weightFocus,
                      (val) => _calculateBMI(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // --- BMI CALCULATOR CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCardSurface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: kGlassBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "BMI Calculator",
                          style: TextStyle(
                            color: kTextWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getBMIColor(_bmi).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getBMIColor(_bmi).withOpacity(0.5)),
                          ),
                          child: Text(
                            _bmi.toStringAsFixed(1),
                            style: TextStyle(
                              color: _getBMIColor(_bmi),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Visual Chart
                    SizedBox(
                      height: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            Expanded(flex: 18, child: Container(color: Colors.blueAccent)), // Underweight
                            Expanded(flex: 7, child: Container(color: Colors.greenAccent)), // Normal
                            Expanded(flex: 5, child: Container(color: Colors.orangeAccent)), // Overweight
                            Expanded(flex: 10, child: Container(color: Colors.redAccent)), // Obese
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Pointer Logic
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double position =
                            (_bmi / 40).clamp(0.0, 1.0) * constraints.maxWidth;
                        position = (position - 6).clamp(0.0, constraints.maxWidth - 12);

                        return Stack(
                          children: [
                            const SizedBox(height: 20, width: double.infinity),
                            Positioned(
                              left: position,
                              child: const Icon(
                                Icons.arrow_drop_up_rounded,
                                color: kTextWhite,
                                size: 24,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Text(
                      _getBMICategory(_bmi),
                      style: TextStyle(
                        color: _getBMIColor(_bmi),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- ACTIONS ---
              _buildActionButton(
                "Change Password",
                Icons.lock_reset_rounded,
                kAccentBlue,
                _showChangePasswordDialog,
              ),
              const SizedBox(height: 15),
              // ONLY CHANGE: logout now confirms and then logs out
              _buildActionButton(
                "Log Out",
                Icons.logout_rounded,
                Colors.redAccent,
                _confirmAndLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildGlossyInput(
    String label,
    TextEditingController controller,
    String suffix,
    FocusNode focusNode,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: kTextGrey.withOpacity(0.8), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          height: 56, // Fixed height ensures alignment
          decoration: BoxDecoration(
            color: kCardSurface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGlassBorder),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              onChanged: onChanged,
              style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                border: InputBorder.none,
                suffixText: suffix,
                suffixStyle: TextStyle(color: kTextGrey.withOpacity(0.6)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(20),
            color: color.withOpacity(0.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blueAccent;
    if (bmi < 25) return Colors.greenAccent;
    if (bmi < 30) return Colors.orangeAccent;
    return Colors.redAccent;
    }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Healthy Weight";
    if (bmi < 30) return "Overweight";
    return "Obese";
  }
}
