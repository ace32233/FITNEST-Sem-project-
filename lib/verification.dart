import 'package:fittness_app/login_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationScreen extends StatefulWidget {
  final String email;

  const VerificationScreen({super.key, required this.email});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_otp.length == 6 && !_loading) {
      _verifyOtp();
    }
  }

  void _onBackspace(int index) {
    if (index > 0 && _controllers[index].text.isEmpty) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6 || _loading) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otp,
        type: OtpType.signup,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on AuthException catch (e) {
      _showError(e.message);
      _clearOtp();
    } catch (_) {
      _showError("Invalid or expired OTP");
      _clearOtp();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    try {
      await Supabase.instance.client.auth.resend(
        email: widget.email,
        type: OtpType.signup,
      );
      _showMessage("OTP resent to ${widget.email}");
    } catch (_) {
      _showError("Failed to resend OTP");
    }
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2852),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  '<',
                  style: TextStyle(color: Colors.white, fontSize: 30),
                ),
              ),

              Center(
                child: Text(
                  'Verification',
                  style: GoogleFonts.pacifico(
                    color: Colors.white,
                    fontSize: size.width * 0.115,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Center(
                child: Column(
                  children: [
                    const Text(
                      "Enter the 6-digit code sent to",
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      widget.email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _otpBox(index),
                ),
              ),

              const SizedBox(height: 30),

              Center(
                child: InkWell(
                  onTap: _loading ? null : _resendOtp,
                  child: const Text(
                    "Resend code",
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 92, 22),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Center(
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0A2852),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(35),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Verify"),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 45,
      height: 55,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        enabled: !_loading,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        decoration: const InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.black,
          border: OutlineInputBorder(borderSide: BorderSide.none),
        ),
        onChanged: (value) => _onChanged(value, index),
        onSubmitted: (_) => _onBackspace(index),
      ),
    );
  }
}
