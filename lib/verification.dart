import 'package:fittness_app/screens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const VerificationScreen(),
    );
  }
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<TextEditingController> _controllers = 
      List.generate(6, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _onBackspace(int index) {
    if (index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _verifyCode() {
    String code = _controllers.map((c) => c.text).join();
    print('Verification code: $code');
    // Add your verification logic here
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height - MediaQuery.of(context).padding.top),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: height * 0.006),
                  
                  // Back button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      '<',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),
                  ),
                  
                  // Title
                  Center(
                    child: Text(
                      'Verification',
                      style: GoogleFonts.pacifico(
                        color: Colors.white,
                        fontSize: width * 0.115,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: height * 0.04),
                  
                  // Subtitle
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Enter the code we\'ve sent by',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: width * 0.058,
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                        ),
                        ),
                        Text(
                          'text to',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: width * 0.058,
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'abc@gmail.com',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: width * 0.058,
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: height * 0.05),
                  
                  // Code input boxes
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.015),
                    child: Row( 
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return Container( 
                          margin: EdgeInsets.symmetric(horizontal: width * 0.008),
                          child: _buildCodeBox(index, width), 
                          ); 
                        }
                      ), 
                    ),
                  ),
                  
                  SizedBox(height: height * 0.05),
                  
                  // Resend code
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Didn\'t receive code?',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: width * 0.04,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        SizedBox(height: height * 0.008),
                        InkWell(
                          onTap: () {
                            print('Resend code tapped');
                            // Add your resend code logic here
                          },
                          child: Text(
                            'Resend code',
                            style: GoogleFonts.poppins(
                              color: const Color.fromARGB(255, 255, 92, 22),
                              fontSize: width * 0.04,
                              fontWeight: FontWeight.w300,
                              decoration: TextDecoration.underline,
                              decorationColor: const Color.fromARGB(255, 255, 92, 22),
                              decorationThickness: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: height * 0.25),
                  
                  // Verify button
                  Center(
                    child: SizedBox(
                      width: width * 0.36,
                      height: height * 0.05,
                      child: ElevatedButton(
                        onPressed: () {
                          // Optional: verify code first
                          _verifyCode();

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0A2852),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          'Verify',
                          style: GoogleFonts.poppins(
                            fontSize: width * 0.04,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index, double width) {
    final boxSize = width * 0.125;
    
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: width * 0.04,
          fontWeight: FontWeight.w400,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => _onCodeChanged(value, index),
        onTap: () {
          _controllers[index].selection = TextSelection.fromPosition(
            TextPosition(offset: _controllers[index].text.length),
          );
        },
        onEditingComplete: () {
          if (index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
        },
      ),
    );
  }
}