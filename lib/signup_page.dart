import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'verification.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    if (password.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        // Check if email confirmation is required
        if (response.session != null) {
          // User is automatically logged in (email confirmation disabled)
          _showSuccess("Account created successfully!");
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        } else {
          // Email confirmation required
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationScreen(email: email),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Something went wrong: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
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

              const SizedBox(height: 10),

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

              _buildField("Full Name", _nameController, "Enter Full Name"),
              SizedBox(height: size.height * 0.025),

              _buildField("Email", _emailController, "Enter Email"),
              SizedBox(height: size.height * 0.025),

              _buildField(
                "Password",
                _passwordController,
                "Enter Password (min 6 characters)",
                obscure: true,
              ),

              SizedBox(height: size.height * 0.18),

              // Create Button
              Center(
                child: SizedBox(
                  width: size.width * 0.4,
                  height: size.height * 0.05,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white70,
                      foregroundColor: const Color(0xFF0D2847),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(size.height * 0.0325),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Color(0xFF0D2847)),
                            ),
                          )
                        : Text(
                            "Create",
                            style: _textStyle(
                              16,
                              const Color(0xFF0D2847),
                              FontWeight.w800,
                              1.5,
                            ),
                          ),
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.04),

              // Login Link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
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
                          style: _textStyle(
                            16,
                            const Color.fromARGB(255, 255, 92, 22),
                            FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6C63FF), width: 2),
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
    double? letterSpacing,
  ]) {
    return GoogleFonts.poppins(
      color: color ?? Colors.white,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }
}