import 'dart:convert';
import 'package:edusaint/screens/home_view.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _otpSent = false;

  // Direct API URLs (no base URL)
  final String sendOtpUrl =
      "https://byte.edusaint.in/api/v1/auth/student/request-login-otp";
  final String verifyOtpUrl =
      "https://byte.edusaint.in/api/v1/auth/student/login-otp";

  // ================= SEND OTP =================
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(sendOtpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": emailController.text.trim()}),
      );

      print("SEND OTP STATUS: ${response.statusCode}");
      print("SEND OTP RESPONSE: ${response.body}");

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200 || data["success"] == true) {
        setState(() => _otpSent = true);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data["message"] ?? "OTP Sent")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Failed to send OTP")),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      print("SEND OTP ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  // ================= VERIFY OTP =================
  Future<void> _verifyOtp() async {
    if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter OTP")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(verifyOtpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "otp": otpController.text.trim(),
        }),
      );

      print("VERIFY OTP STATUS: ${response.statusCode}");
      print("VERIFY OTP RESPONSE: ${response.body}");

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200 || data["success"] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Login Successful")));

        print("TOKEN: ${data['token']}");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeView()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Invalid OTP")),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      print("VERIFY OTP ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(
                      "OTP Login 🔐",
                      style: TextStyle(
                        fontSize: width * 0.07,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _otpSent
                          ? "Enter OTP sent to your email"
                          : "Enter your registered email",
                      style: TextStyle(
                        fontSize: width * 0.04,
                        color: Colors.indigo[500],
                      ),
                    ),

                    SizedBox(height: height * 0.04),

                    // EMAIL FIELD
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your email";
                        } else if (!value.contains('@')) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: height * 0.02),

                    // OTP FIELD
                    if (_otpSent)
                      TextFormField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Enter OTP",
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),

                    SizedBox(height: height * 0.03),

                    // BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: height * 0.06,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_otpSent ? _verifyOtp : _sendOtp),
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
                                _otpSent ? "Verify OTP" : "Send OTP",
                                style: TextStyle(
                                  color: Colors.indigo[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: width * 0.045,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(height: height * 0.04),

                    // BACK BUTTON
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        "Back to Login",
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
      ),
    );
  }
}
