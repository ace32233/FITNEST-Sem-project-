import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final availableHeight = size.height - padding.top - padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Background waves
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundWavePainter(),
            ),
          ),

          /// Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                height: availableHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.09),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: size.height * 0.05),

                      /// Title
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, -38),
                          child: Text(
                            "Create Account",
                            style: GoogleFonts.pacifico(
                              fontSize: size.width * 0.14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.05),

                      /// Name Input
                      const Text("Name", style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      buildInputField("Enter Full Name"),

                      const SizedBox(height: 20),

                      /// Email Input
                      const Text("Email", style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      buildInputField("Enter Email"),

                      const SizedBox(height: 20),

                      /// Password Input
                      const Text("Password", style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      buildInputField("Enter Password", obscure: true),

                      const SizedBox(height: 20),

                    const Spacer(flex: 1),
                      ///CREATE BUTTON
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
                              "Create" ,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: size.width*0.045,
                                fontWeight: FontWeight.bold,
                              )
                            )
                          ),
                        ),

                      const SizedBox(height: 20),

                      /// Go Back to Login Navigation
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageBuilder(const LoginPage()),
                            );
                          },
                          child: const Text.rich(
                            TextSpan(
                              text: "Already have an account? ",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 18),
                              children: [
                                TextSpan(
                                  text: "Log In",
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

  /// Reusable Input Field
  Widget buildInputField(String hint, {bool obscure = false}) {
    return TextField(
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Temporary background painter (replace with your own)
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
