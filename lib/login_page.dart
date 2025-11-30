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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Calculate available height (Screen Height - Top/Bottom Safe Area)
    // This keeps the layout "static" like a full screen page, but scrollable when keyboard opens.
    final padding = MediaQuery.of(context).padding;
    final availableHeight = size.height - padding.top - padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Wave
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundWavePainter(),
            ),
          ),

          /// MAIN CONTENT
          SafeArea(
            child: SingleChildScrollView(
              // Clamping physics prevents weird bouncing on Android/iOS mixed feel
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                // Forces the content to be the height of the screen.
                // When keyboard opens, this height > visible area, so it scrolls.
                height: availableHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.09),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Initial spacing
                      SizedBox(height: size.height * 0.05),

                      /// LOGIN TITLE
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, -38),
                          child: Text(
                            "Login",
                            style: GoogleFonts.pacifico(
                              fontSize: size.width * 0.14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.05),

                      /// Email Input
                      const Text("Email", style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      buildInputField("Enter Email"),

                      const SizedBox(height: 20),

                      /// Password Input
                      const Text("Password", style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      buildInputField("Enter Password", obscure: true),

                      const SizedBox(height: 10),

                      /// Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: Colors.orange,
                                  side: const BorderSide(color: Colors.white54),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text("Remember Me",
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          const Text("Forgot Password?",
                              style: TextStyle(
                                  color: Color.fromARGB(179, 255, 255, 255))),
                        ],
                      ),

                      const Spacer(flex: 1),

                      /// OR Divider
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white54)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Text("OR",
                                style: TextStyle(color: Colors.white)),
                          ),
                          Expanded(child: Divider(color: Colors.white54)),
                        ],
                      ),

                      const Spacer(flex: 1),

                      /// Social Buttons
                      socialButton(Icons.g_mobiledata, "Continue with Google"),
                      const SizedBox(height: 15),
                      socialButton(Icons.apple, "Continue with Apple"),

                      const Spacer(flex: 2),

                      /// LOGIN BUTTON
                      Center(
                        child: Container(
                          width: size.width * 0.35,
                          padding: EdgeInsets.symmetric(
                              vertical: size.height * 0.018),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Text(
                            "Log In",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: size.width * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// SIGN UP Navigation
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageBuilder(const SignUpPage()),
                            );
                          },
                          child: const Text.rich(
                            TextSpan(
                              text: "Don’t have an account? ",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 18),
                              children: [
                                TextSpan(
                                  text: "Sign Up",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Final bottom spacing
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputField(String hint, {bool obscure = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget socialButton(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}

// Painter for the white line wave
class BackgroundWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(0, size.height * 0.6);

    path.cubicTo(
      size.width * 0.3, size.height * 0.5,
      size.width * 0.7, size.height * 0.7,
      size.width, size.height * 0.6,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MaterialPageBuilder extends PageRouteBuilder {
  MaterialPageBuilder(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              FadeTransition(opacity: animation, child: page),
        );
}