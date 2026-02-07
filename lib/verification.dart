import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

// --- GLOSSY DESIGN CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kGlassBorder = Color(0x33FFFFFF); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

class VerificationScreen extends StatelessWidget {
  final String email;

  const VerificationScreen({
    super.key,
    required this.email,
  });

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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Email Icon
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kCardSurface.withOpacity(0.5),
                    border: Border.all(color: kGlassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: kAccentCyan.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.email_outlined,
                    size: size.width * 0.2,
                    color: kAccentCyan,
                  ),
                ),

                SizedBox(height: size.height * 0.05),

                // Title
                Text(
                  "Verify Your Email",
                  style: GoogleFonts.poppins(
                    fontSize: size.width * 0.07,
                    fontWeight: FontWeight.w700,
                    color: kTextWhite,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: size.height * 0.02),

                // Message
                Text(
                  "We've sent a verification link to:",
                  style: GoogleFonts.poppins(
                    fontSize: size.width * 0.04,
                    color: kTextGrey,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: size.height * 0.01),

                // Email Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: kCardSurface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGlassBorder),
                  ),
                  child: Text(
                    email,
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.045,
                      fontWeight: FontWeight.w600,
                      color: kAccentCyan,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: size.height * 0.04),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCardSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGlassBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Please check your email and click on the verification link to activate your account.",
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.038,
                          color: kTextGrey.withOpacity(0.9),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: size.height * 0.02),
                      Text(
                        "Don't forget to check your spam folder!",
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.035,
                          color: Colors.orangeAccent,
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
                      backgroundColor: kAccentCyan,
                      foregroundColor: kDarkSlate,
                      elevation: 5,
                      shadowColor: kAccentCyan.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Go to Login",
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.045,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.03),
              ],
            ),
          ),
        ),
      ),
    );
  }
}