import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home_page.dart';

const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kAccentCyan = Color(0xFF22D3EE); 

class IntroPage extends StatefulWidget {
  final bool isPostLogin;

  const IntroPage({super.key, this.isPostLogin = false});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.8, curve: Curves.elasticOut)),
    );

    if (widget.isPostLogin) {
      // Show immediately if coming from login
      _controller.value = 1.0; 
      _startLoadingProcess();
    } else {
      // Play intro animation on app startup
      _controller.forward();
      // Delay slightly to let animation play before network requests
      Future.delayed(const Duration(milliseconds: 2000), _startLoadingProcess);
    }
  }

  Future<void> _startLoadingProcess() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      try {
        // 1. Fetch ALL data needed for Home Page
        // This ensures the Home Page has data *before* it renders
        final data = await HomePage.preloadData();
        
        if (!mounted) return;

        // 2. Navigate to Home Page WITH the data
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              // IMPORTANT: Pass the preloaded data here
              child: HomePage(initialData: data), 
            ),
          ),
        );
      } catch (e) {
        // If data fetch fails, go to login
        if (mounted) _navigateToLogin();
      }
    } else {
      if (mounted) _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const LoginPage(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kDarkSlate, kDarkTeal],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "FITNEST",
                    style: GoogleFonts.suezOne(
                      color: kAccentCyan,
                      fontSize: size.width * 0.15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 5.5,
                      shadows: [
                        BoxShadow(
                          color: kAccentCyan.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Loading Indicator
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: kAccentCyan.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Dynamic text based on context
                  Text(
                    widget.isPostLogin ? "Syncing profile..." : "Loading...",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}