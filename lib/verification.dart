import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

class VerificationScreen extends StatelessWidget {
  final String email;

  const VerificationScreen({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email Icon
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: size.width * 0.2,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: size.height * 0.05),

              // Title
              Text(
                "Verify Your Email",
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.07,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: size.height * 0.02),

              // Message
              Text(
                "We've sent a verification link to:",
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.04,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: size.height * 0.01),

              // Email Display
              Text(
                email,
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.045,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: size.height * 0.04),

              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "Please check your email and click on the verification link to activate your account.",
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.038,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.02),
                    Text(
                      "Don't forget to check your spam folder!",
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.035,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(height: size.height * 0.06),

              // Go to Login Button
              SizedBox(
                width: size.width * 0.6,
                height: size.height * 0.055,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    "Go to Login",
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.045,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D2847),
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
}