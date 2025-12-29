import 'package:fittness_app/gender_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';

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

  //Auto-login
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    final session = supabase.auth.currentSession;

    if (session != null && rememberMe && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GenderScreen()),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  //Login using Supabase
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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GenderScreen()),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Login failed. Try again.');
    } finally {
      setState(() => _isLoading = false);
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

              //Title
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

              //Remember Me
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

              //Login Button
              Center(
                child: SizedBox(
                  width: size.width * 0.6,
                  height: size.height * 0.055,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
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

              //Sign Up
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
