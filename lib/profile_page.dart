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
    _ageFocus.addListener(() { if (!_ageFocus.hasFocus) _saveProfile(); });
    _heightFocus.addListener(() { if (!_heightFocus.hasFocus) _saveProfile(); });
    _weightFocus.addListener(() { if (!_weightFocus.hasFocus) _saveProfile(); });
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

  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;
    setState(() {
      _email = user?.email ?? 'No Email';
    });

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ageController.text = prefs.getString('profile_age') ?? '25';
      _heightController.text = prefs.getString('profile_height') ?? '175';
      _weightController.text = prefs.getString('profile_weight') ?? '70';
      _gender = prefs.getString('profile_gender') ?? 'Male';
      _calculateBMI(); 
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_age', _ageController.text);
    await prefs.setString('profile_height', _heightController.text);
    await prefs.setString('profile_weight', _weightController.text);
    await prefs.setString('profile_gender', _gender);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kGlassBorder)),
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
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: kGlassBorder), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kAccentCyan), borderRadius: BorderRadius.all(Radius.circular(12))),
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
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: kGlassBorder), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kAccentCyan), borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator(color: kAccentCyan, backgroundColor: kCardSurface),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context), 
                child: const Text("Cancel", style: TextStyle(color: kTextGrey))
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (oldPasswordController.text.isEmpty || newPasswordController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters.")));
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
                        const SnackBar(backgroundColor: Colors.green, content: Text("Password changed successfully!")),
                      );
                    }
                  } on AuthException catch (e) {
                    if (context.mounted) {
                      setState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.red, content: Text(e.message)), // e.g. "Invalid login credentials"
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
                style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: kDarkSlate),
                child: const Text("Update"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if(mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/intro', (route) => false); 
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
                    BoxShadow(color: kAccentCyan.withOpacity(0.15), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: const Icon(Icons.person_rounded, size: 50, color: kTextGrey),
              ),
              const SizedBox(height: 16),
              Text(
                _email,
                style: const TextStyle(color: kTextWhite, fontSize: 16, fontWeight: FontWeight.w500),
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
                    )
                  ),
                  const SizedBox(width: 15),
                  // Gender Dropdown 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Gender", style: TextStyle(color: kTextGrey.withOpacity(0.8), fontSize: 12)),
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
                              style: const TextStyle(color: kTextWhite, fontSize: 16, fontWeight: FontWeight.bold),
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
                      (val) => _calculateBMI()
                    )
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildGlossyInput(
                      "Weight", 
                      _weightController, 
                      "kg", 
                      _weightFocus,
                      (val) => _calculateBMI()
                    )
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
                        const Text("BMI Calculator", style: TextStyle(color: kTextWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getBMIColor(_bmi).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getBMIColor(_bmi).withOpacity(0.5)),
                          ),
                          child: Text(
                            _bmi.toStringAsFixed(1),
                            style: TextStyle(color: _getBMIColor(_bmi), fontWeight: FontWeight.bold, fontSize: 16),
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
                        double position = (_bmi / 40).clamp(0.0, 1.0) * constraints.maxWidth;
                        position = (position - 6).clamp(0.0, constraints.maxWidth - 12); 
                        
                        return Stack(
                          children: [
                            const SizedBox(height: 20, width: double.infinity),
                            Positioned(
                              left: position,
                              child: const Icon(Icons.arrow_drop_up_rounded, color: kTextWhite, size: 24),
                            ),
                          ],
                        );
                      },
                    ),
                    Text(
                      _getBMICategory(_bmi),
                      style: TextStyle(color: _getBMIColor(_bmi), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- ACTIONS ---
              _buildActionButton("Change Password", Icons.lock_reset_rounded, kAccentBlue, _showChangePasswordDialog),
              const SizedBox(height: 15),
              _buildActionButton("Log Out", Icons.logout_rounded, Colors.redAccent, _logout),
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
    Function(String) onChanged
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
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
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