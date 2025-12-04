import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GenderScreen(),
    );
  }
}

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Text(
                  'Tell us About Yourself',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'To give you better experience',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 40),

                // Male
                buildGenderOption('male', Icons.male),
                const SizedBox(height: 40),

                // Female
                buildGenderOption('female', Icons.female),

                const Spacer(),

                // NEXT BUTTON
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: ElevatedButton(
                    onPressed: selected == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NextPage(selected: selected!),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 45, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildGenderOption(String gender, IconData icon) {
    bool isSelected = selected == gender;

    return GestureDetector(
      onTap: () => setState(() => selected = gender),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFB300),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 4)
                  : null,
            ),
            child: Icon(icon, size: 70, color: Colors.black),
          ),
          const SizedBox(height: 12),
          Text(
            gender[0].toUpperCase() + gender.substring(1),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          )
        ],
      ),
    );
  }
}

// ------------------ NEXT PAGE ------------------
class NextPage extends StatelessWidget {
  final String selected;
  const NextPage({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Next Page')),
      body: Center(
        child: Text(
          'You selected: $selected',
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}



