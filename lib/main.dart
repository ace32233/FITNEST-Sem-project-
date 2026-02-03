import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/rendering.dart';

// --- PAGE IMPORTS ---
import 'intro_page.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'gender_page.dart';

void main() async {
  // Keep your debug flags
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;

  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables
  await dotenv.load(fileName: ".env");
  print("ENV LOADED => ${dotenv.env}");
  print("KEY1 => ${dotenv.env['EXERCISE_API_KEY_1']}");




  // Get Supabase credentials from .env
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Validate credentials exist
  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('Supabase credentials not found in .env file');
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness App',
      // --- FIX: Global Dark Theme ---
      // This ensures backgrounds don't flash white during transitions
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // kDarkSlate
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      // --- FIX: Set IntroPage as Home ---
      // IntroPage handles the Auth Check & Loading animation
      home: const IntroPage(), 
      
      // --- FIX: Named Routes ---
      // Required for Profile Page logout logic
      routes: {
        '/intro': (context) => const IntroPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/onboarding': (context) => const GenderScreen(),
      },
    );
  }
}