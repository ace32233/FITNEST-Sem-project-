import 'package:fittness_app/screens/verification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              SizedBox(height: size.height * 0.001),
              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  '<',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: size.width * 0.08,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.0005),

              // Title
              Center(
                child: Text(
                  "Create Account",
                  style: GoogleFonts.pacifico(
                    fontSize: size.width * 0.115,
                    letterSpacing: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.08),

              // Name Field
              _buildField("Full Name", _nameController, "Enter Full Name"),
              SizedBox(height: size.height * 0.025),

              // Email Field
              _buildField("Email", _emailController, "Enter Email"),
              SizedBox(height: size.height * 0.025),

              // Password Field
              _buildField("Password", _passwordController, "Enter Password", obscure: true),
              SizedBox(height: size.height * 0.18),

              // Create Button
              Center(
                child: SizedBox(
                  width: size.width * 0.4,
                  height: size.height * 0.05,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VerificationScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D2847),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(size.height * 0.0325),
                      ),
                    ),
                    child: Text(
                      "Create",
                      style: _textStyle(16, const Color(0xFF0D2847), FontWeight.w800, 1.5),
                    ),
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.04),

              // Login Link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: Text.rich(
                    TextSpan(
                      text: "Already have an account? ",
                      style: _textStyle(16, Colors.white70),
                      children: [
                        TextSpan(
                          text: "Log In",
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

  TextStyle _textStyle(double size, [Color? color, FontWeight? weight, double? letterSpacing]) {
    return GoogleFonts.poppins(
      color: color ?? Colors.white,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }
}