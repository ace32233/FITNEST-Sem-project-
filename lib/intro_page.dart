import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'login_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Text(
                "FITNEST",
                style: GoogleFonts.suezOne(
                  color: Colors.white,
                  fontSize: size.width * 0.15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 5.5,
                ),
              ),
            ),

            Positioned(
              bottom: size.height * 0.1,
              left: size.width * 0.2,
              right: size.width * 0.2,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 600),
                      pageBuilder: (_, animation, __) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: const LoginPage(),
                          ),
                        );
                      },
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: size.height * 0.018),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Center(
                    child: Text(
                      "Get Started",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: size.width * 0.045,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}