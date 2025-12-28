import 'package:fittness_app/screens/gender_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _rememberMe = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToGender() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GenderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.0005),
              
              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('<',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: size.width * 0.08,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.0001),

              // Title
              Center(
                child: Text("Login",
                  style: GoogleFonts.pacifico(
                    fontSize: size.width * 0.13,
                    letterSpacing: 3.0,
                    color: Colors.white,
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.04),

              // Email Field
              _buildField("Email", _emailController, "Enter Email"),
              SizedBox(height: size.height * 0.025),

              // Password Field
              _buildField("Password", _passwordController, "Enter Password", obscure: true),
              SizedBox(height: size.height * 0.015),

              // Remember Me & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: const Color(0xFF6C63FF),
                          side: const BorderSide(color: Colors.white70, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text("Remember Me", style: _textStyle(14, Colors.white, FontWeight.w300)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text("Forgot Password?", style: _textStyle(14, Colors.white70, FontWeight.w300)),
                  ),
                ],
              ),

              SizedBox(height: size.height * 0.04),

              // Login Button
              _buildButton("Log In", _navigateToGender, size.height, size.width,
                bgColor: Colors.white, textColor: const Color(0xFF0D2847), rounded: true),

              SizedBox(height: size.height * 0.03),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white54, thickness: 2)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Text("OR", style: _textStyle(14, Colors.white70)),
                  ),
                  const Expanded(child: Divider(color: Colors.white54, thickness: 2)),
                ],
              ),

              SizedBox(height: size.height * 0.03),

              // Social Buttons
              _buildSocialButton(
                child: Image.network(
                  'https://www.google.com/favicon.ico',
                  width: 25,
                  height: 25,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.g_mobiledata, color: Colors.white, size: 25),
                ),
                text: "Continue with Google",
                size: size,
              ),
              SizedBox(height: size.height * 0.02),
              _buildIconButton(Icons.apple, "Continue with Apple", size),
              SizedBox(height: size.height * 0.02),
              _buildIconButton(Icons.person_outline, "Continue as Guest", size, onTap: _navigateToGender),
              SizedBox(height: size.height * 0.04),

              // Sign Up Link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage())),
                  child: Text.rich(
                    TextSpan(
                      text: "Don't have an account? ",
                      style: _textStyle(16, Colors.white),
                      children: [
                        TextSpan(
                          text: "Sign Up",
                          style: _textStyle(16, const Color.fromARGB(255, 255, 92, 22), FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool obscure = false}) {
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, VoidCallback onTap, double height, double width,
      {Color bgColor = const Color(0xFF1E3A5F), Color textColor = Colors.white, bool rounded = false}) {
    return Center(
      child: SizedBox(
      width: width * 0.6,
      height: height * 0.052,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rounded ? height * 0.035 : 12),
          ),
        ),
        child: Text(text, style: _textStyle(22, textColor, FontWeight.w600, 2.5)),
      ),
      ),
    );
  }

    Widget _buildIconButton(IconData icon, String text, Size size, {VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: size.height * 0.056,
      child: Material(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: size.width * 0.08),
              const SizedBox(width: 12),
              Text(text, style: _textStyle(15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required Widget child, required String text, required Size size, VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: size.height * 0.056,
      child: Material(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child,
              const SizedBox(width: 12),
              Text(text, style: _textStyle(15)),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _textStyle(double size, [Color? color, FontWeight? weight, double? letterSpacing]) {
    return GoogleFonts.poppins(
      color: color ?? Colors.white,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }
}