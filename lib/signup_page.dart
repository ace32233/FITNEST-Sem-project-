import 'package:flutter/material.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          "Signup Page",
          style: TextStyle(color: Colors.white, fontSize: 26),
        ),
      ),
    );
  }
}
