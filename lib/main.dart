import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'intro_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IntroPage(),
    );
  }
}


