import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'verification.dart';

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kGlassBorder = Color(0x33FFFFFF); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

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
      final supabase = Supabase.instance.client;
      
      // Sign up the user
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        // The database trigger will automatically create the profile
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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_ios_new, color: kTextWhite, size: 24),
                ),

                const SizedBox(height: 20),

                // Title
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kCardSurface.withOpacity(0.5),
                          border: Border.all(color: kGlassBorder),
                          boxShadow: [
                            BoxShadow(
                              color: kAccentCyan.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, size: 40, color: kAccentCyan),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Create Account",
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: kTextWhite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Join us to start your journey",
                        style: TextStyle(color: kTextGrey.withOpacity(0.8), fontSize: 16),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.05),

                // Inputs
                _buildGlossyTextField(
                  controller: _nameController,
                  label: "Full Name",
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildGlossyTextField(
                  controller: _emailController,
                  label: "Email",
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                _buildGlossyTextField(
                  controller: _passwordController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),

                SizedBox(height: size.height * 0.05),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentCyan,
                      foregroundColor: kDarkSlate,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: kDarkSlate),
                          )
                        : const Text(
                            "Sign Up",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Link
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: const TextStyle(color: kTextGrey),
                        children: [
                          TextSpan(
                            text: "Log In",
                            style: GoogleFonts.poppins(
                              color: kAccentCyan,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildGlossyTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: kTextWhite),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kTextGrey),
          labelText: label,
          labelStyle: const TextStyle(color: kTextGrey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}