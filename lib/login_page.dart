import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import 'gender_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _rememberMe = false;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // Auto-login if session exists
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final session = supabase.auth.currentSession;

    if (session != null && rememberMe && mounted) {
      // Check if user has completed onboarding
      await _navigateBasedOnOnboarding();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Login using Supabase
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', _rememberMe);

        // Ensure profile exists (in case it wasn't created by trigger)
        await _ensureProfileExists(response.user!);

        // Navigate based on onboarding status
        await _navigateBasedOnOnboarding();
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Login failed. Try again. Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Ensure profile exists for the user
  Future<void> _ensureProfileExists(User user) async {
    try {
      // Check if profile exists
      final profileResponse = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // If no profile exists, create one
      if (profileResponse == null) {
        await supabase.from('profiles').insert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? '',
          'email': user.email ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Profile created for user: ${user.id}');
      }
    } catch (e) {
      debugPrint('Error ensuring profile exists: $e');
    }
  }

  // Check if user completed onboarding and navigate accordingly
  Future<void> _navigateBasedOnOnboarding() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Ensure profile exists
      await _ensureProfileExists(user);

      // Check if user has completed fitness onboarding
      final fitnessResponse = await supabase
          .from('user_fitness')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (fitnessResponse == null) {
        // First time user - go to onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GenderScreen()),
        );
      } else {
        // Returning user - go to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      debugPrint('Error checking onboarding: $e');
      // Default to onboarding if error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GenderScreen()),
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Title
              Center(
                child: Text(
                  "Login",
                  style: GoogleFonts.pacifico(
                    fontSize: size.width * 0.13,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.04),

              _buildField("Email", _emailController, "Enter Email"),
              SizedBox(height: size.height * 0.025),

              _buildField(
                "Password",
                _passwordController,
                "Enter Password",
                obscure: true,
              ),

              SizedBox(height: size.height * 0.02),

              // Remember Me
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                  Text(
                    "Remember Me",
                    style: _textStyle(14, Colors.white),
                  ),
                ],
              ),

              SizedBox(height: size.height * 0.03),

              // Login Button
              Center(
                child: SizedBox(
                  width: size.width * 0.6,
                  height: size.height * 0.055,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            "Log In",
                            style: _textStyle(
                              20,
                              const Color(0xFF0D2847),
                              FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.04),

              // Sign Up
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: "Don't have an account? ",
                      style: _textStyle(16),
                      children: [
                        TextSpan(
                          text: "Sign Up",
                          style: _textStyle(
                            16,
                            Colors.orange,
                            FontWeight.w500,
                          ),
                        ),
                      ],
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

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint, {
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _textStyle(16)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: _textStyle(15),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF3C3C3C),
            hintText: hint,
            hintStyle: _textStyle(15, Colors.white38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _textStyle(
    double size, [
    Color? color,
    FontWeight? weight,
  ]) {
    return GoogleFonts.poppins(
      fontSize: size,
      color: color ?? Colors.white,
      fontWeight: weight,
    );
  }
}