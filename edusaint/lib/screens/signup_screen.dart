import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'splash_screen2.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController syllabusController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController subjectsController = TextEditingController();
  final TextEditingController lang2Controller = TextEditingController();
  final TextEditingController lang3Controller = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  // Dropdown data
  List<dynamic> classesList = [];
  bool isClassLoading = false;

  // Selected values
  String? selectedSyllabus;
  String? selectedClass;
  String? selectedSubjects;

  bool _isObscured = true;
  bool _isConfirmObscured = true;
  bool _isLoading = false;

  final String apiUrl = "https://byte.edusaint.in/api/v1/auth/register";

  // Validate only fields in the current step
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Basic Details
        if (nameController.text.trim().isEmpty) {
          _showFieldError("Please enter your name");
          return false;
        }
        if (!emailController.text.contains('@')) {
          _showFieldError("Enter a valid email");
          return false;
        }
        if (mobileController.text.trim().length != 10) {
          _showFieldError("Enter a valid 10-digit mobile number");
          return false;
        }
        return true;
      case 1: // Academic Details
        if (syllabusController.text.trim().isEmpty) {
          _showFieldError("Please enter syllabus (CBSE/ICSE/State)");
          return false;
        }
        if (classController.text.trim().isEmpty) {
          _showFieldError("Please enter class (e.g., 8th)");
          return false;
        }
        return true;
      case 2: // Languages
        if (lang2Controller.text.trim().isEmpty) {
          _showFieldError("Please enter second language");
          return false;
        }
        if (lang3Controller.text.trim().isEmpty) {
          _showFieldError("Please enter third language");
          return false;
        }
        return true;
      case 3: // Password setup (final step validation too)
        if (passwordController.text.length < 6) {
          _showFieldError("Password must be at least 6 characters");
          return false;
        }

        if (confirmController.text != passwordController.text) {
          _showFieldError("Passwords do not match");
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showFieldError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> fetchClasses() async {
    setState(() => isClassLoading = true);

    try {
      final response = await http.get(
        Uri.parse("https://byte.edusaint.in/api/v1/classes"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          classesList = data["classes"] ?? [];

          if (!classesList.any((item) => item["name"] == selectedClass)) {
            selectedClass = null;
            classController.clear();
          }
        });
      }
    } catch (e) {
      debugPrint("Class API Error: $e");
    }

    setState(() => isClassLoading = false);
  }

  Future<void> _submitSignup() async {
    // Validate final step (also ensure earlier steps valid)
    for (int i = 0; i < _totalSteps; i++) {
      final prev = _currentStep;
      _currentStep = i;
      if (!_validateCurrentStep()) {
        setState(() {}); // ensure step UI updates
        // jump to failing step
        _pageController.jumpToPage(i);
        return;
      }
      _currentStep = prev;
    }

    setState(() => _isLoading = true);

    final payload = {
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
      "name": nameController.text.trim(),
      "mobile": mobileController.text.trim(),
      "syllabus": syllabusController.text.trim(),
      "class": classController.text.trim(),
      "subjects": subjectsController.text.trim(),
      "second_language": lang2Controller.text.trim(),
      "third_language": lang3Controller.text.trim(),
      "date": DateTime.now().toIso8601String().split("T")[0],
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      setState(() => _isLoading = false);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        String? token =
            data["token"] ?? data["data"]?["token"] ?? data["access_token"];

        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("token", token);
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen2()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Signup failed"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Card builder with internal Next/Prev buttons at bottom of card
  Widget _stepCard({
    required String title,
    required List<Widget> children,
    required Widget actionButtons, // placed inside card bottom row
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 16),
          actionButtons,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    syllabusController.dispose();
    classController.dispose();
    subjectsController.dispose();
    lang2Controller.dispose();
    lang3Controller.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A6BEE), Color(0xFF3A5DC8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 36),
                Text(
                  "Create Your Account ✨",
                  style: TextStyle(
                    fontSize: width * 0.07,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Let's get you started!",
                  style: TextStyle(
                    fontSize: width * 0.045,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: width * 0.92,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(
                          height: height * 0.55,
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            onPageChanged: (idx) =>
                                setState(() => _currentStep = idx),
                            children: [
                              // Step 0 - Basic Details
                              _stepCard(
                                title: "Basic Details",
                                children: [
                                  TextFormField(
                                    controller: nameController,
                                    decoration: _fieldDecoration("Full Name"),
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: emailController,
                                    decoration: _fieldDecoration("Email"),
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: mobileController,
                                    decoration: _fieldDecoration(
                                      "Mobile Number",
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                                actionButtons: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SizedBox(
                                      width: 8,
                                    ), // placeholder to align Prev to left visually
                                    ElevatedButton(
                                      onPressed: _nextStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Next",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Step 1 - Academic Details
                              _stepCard(
                                title: "Academic Details",
                                children: [
                                  // Syllabus Dropdown
                                  DropdownButtonFormField<String>(
                                    value: selectedSyllabus,
                                    decoration: _fieldDecoration("Board"),
                                    items: const [
                                      DropdownMenuItem(
                                        value: "CBSE",
                                        child: Text("CBSE"),
                                      ),
                                      DropdownMenuItem(
                                        value: "ICSE",
                                        child: Text("ICSE"),
                                      ),
                                      DropdownMenuItem(
                                        value: "State",
                                        child: Text("State Board"),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedSyllabus = value;
                                        syllabusController.text = value ?? "";
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Class Dropdown (API based)
                                  isClassLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : DropdownButtonFormField<String>(
                                          value: classesList.isEmpty
                                              ? null
                                              : selectedClass,
                                          decoration: _fieldDecoration("Class"),
                                          items: classesList
                                              .map<DropdownMenuItem<String>>((
                                                item,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: item["name"]
                                                      .toString(),
                                                  child: Text(
                                                    item["name"].toString(),
                                                  ),
                                                );
                                              })
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedClass = value;
                                              classController.text =
                                                  value ?? "";
                                            });
                                          },
                                        ),

                                  const SizedBox(height: 12),
                                ],
                                actionButtons: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _prevStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade400,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text("Previous"),
                                    ),
                                    ElevatedButton(
                                      onPressed: _nextStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Next",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Step 2 - Languages
                              _stepCard(
                                title: "Languages",
                                children: [
                                  TextFormField(
                                    controller: lang2Controller,
                                    decoration: _fieldDecoration(
                                      "Second Language",
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: lang3Controller,
                                    decoration: _fieldDecoration(
                                      "Third Language",
                                    ),
                                  ),
                                ],
                                actionButtons: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _prevStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade400,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text("Previous"),
                                    ),
                                    ElevatedButton(
                                      onPressed: _nextStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Next",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Step 3 - Password Setup
                              _stepCard(
                                title: "Password Setup",
                                children: [
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: _isObscured,
                                    decoration: InputDecoration(
                                      labelText: "Password (min 6 characters)",

                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isObscured
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.indigo,
                                        ),
                                        onPressed: () => setState(
                                          () => _isObscured = !_isObscured,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: confirmController,
                                    obscureText: _isConfirmObscured,
                                    decoration: InputDecoration(
                                      labelText: "Confirm Password",
                                      prefixIcon: const Icon(
                                        Icons.lock_person_outlined,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isConfirmObscured
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.indigo,
                                        ),
                                        onPressed: () => setState(
                                          () => _isConfirmObscured =
                                              !_isConfirmObscured,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                actionButtons: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _prevStep,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade400,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text("Previous"),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _submitSignup,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              "Sign Up",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Log In",
                                style: TextStyle(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
