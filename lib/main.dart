import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'intro_page.dart';
import 'gender_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://mjijxsojtbshsauguwjf.supabase.co',
    anonKey: 'sb_publishable_Ed9aAKGTLev20EWZmbmP7w_2mrQUCAM',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness App',
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// Auth Gate - Determines where to route user
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  Widget _destination = const IntroPage();

  @override
  void initState() {
    super.initState();
    _checkAuthAndOnboarding();
  }

  Future<void> _checkAuthAndOnboarding() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        // Not logged in - show intro page
        setState(() {
          _destination = const IntroPage();
          _isLoading = false;
        });
        return;
      }

      // User is logged in
      final user = session.user;

      // Ensure profile exists
      await _ensureProfileExists(user);

      // Check if they completed onboarding
      final fitnessResponse = await supabase
          .from('user_fitness')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (fitnessResponse == null) {
        // No fitness data - first time user, show onboarding
        setState(() {
          _destination = const GenderScreen();
          _isLoading = false;
        });
      } else {
        // Has fitness data - returning user, go to home
        setState(() {
          _destination = const HomePage();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking auth: $e');
      setState(() {
        _destination = const IntroPage();
        _isLoading = false;
      });
    }
  }

  // Ensure profile exists for the user
  Future<void> _ensureProfileExists(User user) async {
    try {
      final supabase = Supabase.instance.client;

      // Check if profile exists
      final profileResponse = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // If no profile exists, create one
      if (profileResponse == null) {
        await supabase.from('profiles').insert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? '',
          'email': user.email ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Profile created for user: ${user.id}');
      }
    } catch (e) {
      debugPrint('Error ensuring profile exists: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A2852),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return _destination;
  }
}
