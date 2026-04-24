import 'dart:async';
import 'package:flutter/material.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  bool _isLoading = false;

  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _timer;

  List<String> otpDigits = ["", "", "", ""];

  final List<FocusNode> focusNodes = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _canResend = false;

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    String otp = otpDigits.join().trim();

    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid 4 digit OTP")),
      );
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _isLoading = false);

    /// Dummy OTP check
    if (otp == "1234") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP verified successfully")),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: widget.email),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  void _resendOtp() {
    if (!_canResend) return;

    setState(() {
      otpDigits = ["", "", "", ""];
    });

    for (var node in focusNodes) {
      node.unfocus();
    }

    focusNodes.first.requestFocus();

    _startTimer();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("OTP resent")));
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (var node in focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  Widget otpBox(int index, double width) {
    return SizedBox(
      width: width * 0.16,
      child: TextField(
        focusNode: focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(
          fontSize: width * 0.06,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[800],
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.indigo.shade200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
          ),
        ),
        onChanged: (value) {
          otpDigits[index] = value;

          if (value.isNotEmpty && index < 3) {
            FocusScope.of(context).requestFocus(focusNodes[index + 1]);
          }

          if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(focusNodes[index - 1]);
          }

          /// Auto verify when all digits entered
          if (otpDigits.join().length == 4) {
            _verifyOtp();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A6BEE), Color(0xFF3A5DC8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: width * 0.9,
              padding: EdgeInsets.all(width * 0.07),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Verify OTP 🔑",
                    style: TextStyle(
                      fontSize: width * 0.07,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[800],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "OTP sent to ${widget.email}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: width * 0.04,
                      color: Colors.indigo[500],
                    ),
                  ),
                  SizedBox(height: height * 0.04),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      otpBox(0, width),
                      otpBox(1, width),
                      otpBox(2, width),
                      otpBox(3, width),
                    ],
                  ),

                  SizedBox(height: height * 0.02),

                  GestureDetector(
                    onTap: _canResend ? _resendOtp : null,
                    child: Text(
                      _canResend
                          ? "Resend OTP"
                          : "Resend OTP in $_secondsRemaining sec",
                      style: TextStyle(
                        color: _canResend ? Colors.indigo : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: height * 0.03),

                  SizedBox(
                    width: double.infinity,
                    height: height * 0.06,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3A5DC8),
                              ),
                            )
                          : Text(
                              "Verify OTP",
                              style: TextStyle(
                                color: Colors.indigo[800],
                                fontWeight: FontWeight.bold,
                                fontSize: width * 0.045,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: height * 0.04),

                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
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
