import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'profile_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final Color themeColor = const Color(0xFF1B2B57);
  final Color softWhite = const Color(0xFFF9FAFB);

  bool isLoading = true;
  bool isUpdating = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController classController = TextEditingController();

  String? token;
  int? studentId;

  String? imagePath;
  File? selectedImageFile;

  final ImagePicker _picker = ImagePicker();
  final String baseUrl = 'https://byte.edusaint.in';

  @override
  void initState() {
    super.initState();
    initProfile();
  }

  // ---------------- INIT ----------------
  Future<void> initProfile() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString("token");
    studentId = prefs.getInt("student_id");

    if (token == null || studentId == null) {
      debugPrint("❌ Missing token or studentId");
      setState(() => isLoading = false);
      return;
    }

    await fetchProfile();
  }

  // ---------------- FETCH PROFILE ----------------
  Future<void> fetchProfile() async {
    try {
      setState(() => isLoading = true);

      final response = await http.get(
        Uri.parse("$baseUrl/api/v1/students/69"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to load profile");
      }

      final data = jsonDecode(response.body);

      setState(() {
        nameController.text = data['name']?.toString() ?? '';
        emailController.text = data['email']?.toString() ?? '';
        phoneController.text = data['mobile']?.toString() ?? '';
        classController.text = data['class']?.toString() ?? '';
        imagePath = data['image'] ?? '';
      });
    } catch (e) {
      debugPrint("PROFILE ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load profile")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------------- IMAGE PROVIDER ----------------
  ImageProvider<Object>? _avatarImageProvider() {
    if (selectedImageFile != null) {
      return FileImage(selectedImageFile!);
    }

    if (imagePath != null && imagePath!.isNotEmpty) {
      if (imagePath!.startsWith("http")) {
        return NetworkImage(imagePath!);
      } else {
        return NetworkImage("$baseUrl$imagePath");
      }
    }

    return null;
  }

  // ---------------- PICK IMAGE ----------------
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);

    if (picked != null) {
      setState(() {
        selectedImageFile = File(picked.path);
      });
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        );
      },
    );
  }

  // ---------------- UPDATE PROFILE DATA ----------------
  Future<void> updateProfileData() async {
    final response = await http.post(
      Uri.parse("$baseUrl/api/v1/students/69"),
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
      body: {
        "name": nameController.text.trim(),
        "class": classController.text.trim(),
        "mobile": phoneController.text.trim(),
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Profile update failed");
    }
  }

  // ---------------- UPDATE AVATAR ----------------
  Future<void> updateAvatar() async {
    if (selectedImageFile == null) return;

    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/api/v1/students/69/avatar"),
    );

    request.headers["Authorization"] = "Bearer $token";

    request.files.add(
      await http.MultipartFile.fromPath(
        "avatar", // ⚠️ if backend expects "image", change here
        selectedImageFile!.path,
      ),
    );

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception("Avatar upload failed");
    }
  }

  // ---------------- MAIN UPDATE ----------------
  Future<void> updateProfile() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Name cannot be empty")));
      return;
    }

    setState(() => isUpdating = true);

    try {
      await updateProfileData();
      await updateAvatar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } catch (e) {
      debugPrint("UPDATE ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Update failed")));
    } finally {
      setState(() => isUpdating = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: softWhite,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
            child: Column(
              children: [
                // AVATAR
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _avatarImageProvider(),
                      child: _avatarImageProvider() == null
                          ? Icon(Icons.person, size: 50, color: themeColor)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImageOptions,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                _buildField("Name", nameController),
                _buildField("Email", emailController, readOnly: true),
                _buildField("Mobile", phoneController),
                _buildField("Class", classController),

                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: isUpdating ? null : updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Update"),
                ),
              ],
            ),
          ),

          // TOP BAR
          Container(
            height: 100,
            color: themeColor,
            padding: const EdgeInsets.only(top: 40),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  "Edit Profile",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
