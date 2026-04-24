import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'mainscaffold.dart';
import 'learn_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeView extends StatefulWidget {
  final int? classId;

  const HomeView({super.key, this.classId});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int? _classId;
  String studentName = "Student";
  bool isLoading = true;

  List<Course> courses = [];
  List<ClassItem> classes = [];
  ClassItem? selectedClass;

  String? _authToken;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ================= INIT =================
  Future<void> _initialize() async {
    setState(() => isLoading = true);

    await _loadToken();
    await _loadSavedClass();

    await Future.wait([_loadClasses(), _loadStudentName()]);

    await _loadCourses();

    setState(() => isLoading = false);
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString("token");

    print("TOKEN LOADED: $_authToken"); // debug
  }

  Future<void> _loadSavedClass() async {
    final prefs = await SharedPreferences.getInstance();
    _classId = prefs.getInt("selected_class_id") ?? 6;
  }

  Future<void> _saveClass(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("selected_class_id", id);
  }

  // ================= PROFILE =================
  // ================= PROFILE =================
  Future<void> _loadStudentName() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      studentName = prefs.getString("name") ?? "Student";
    });

    print("LOADED NAME: $studentName"); // debug
  }

  // ================= CLASSES =================
  Future<void> _loadClasses() async {
    try {
      final res = await http.get(
        Uri.parse("https://byte.edusaint.in/api/v1/classes"),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List data = decoded['data'] ?? [];

        if (data.isNotEmpty) {
          classes = data.map((e) => ClassItem.fromJson(e)).toList();
        }
      }

      if (classes.isEmpty) {
        classes = List.generate(
          12,
          (i) => ClassItem(id: i + 1, name: "Class ${i + 1}"),
        );
      }

      selectedClass = classes.firstWhere(
        (c) => c.id == _classId,
        orElse: () => classes.first,
      );

      _classId = selectedClass!.id;

      setState(() {});
    } catch (e) {
      debugPrint("Class Error: $e");
    }
  }

  // ================= COURSES =================
  Future<void> _loadCourses() async {
    if (_classId == null) return;

    setState(() => isLoading = true);

    try {
      final res = await http.get(
        Uri.parse("https://byte.edusaint.in/api/v1/classes/$_classId/courses"),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List data = decoded['data'] ?? [];

        courses = data.map((e) => Course.fromJson(e)).toList();
      } else {
        courses = [];
      }
    } catch (e) {
      courses = [];
    }

    setState(() => isLoading = false);
  }

  // ================= SUBJECT ICON + COLOR =================
  IconData getIcon(String name) {
    final n = name.toLowerCase();

    if (n.contains("math")) return Icons.calculate;
    if (n.contains("science")) return Icons.science;
    if (n.contains("english")) return Icons.menu_book;
    if (n.contains("social")) return Icons.public;
    if (n.contains("computer")) return Icons.computer;
    if (n.contains("physics")) return Icons.bolt;
    if (n.contains("chemistry")) return Icons.science;
    if (n.contains("biology")) return Icons.biotech;

    return Icons.book;
  }

  List<Color> getGradient(int index) {
    final gradients = [
      [Color(0xFF667EEA), Color(0xFF764BA2)],
      [Color(0xFF43E97B), Color(0xFF38F9D7)],
      [Color(0xFFFFA726), Color(0xFFFF7043)],
      [Color(0xFF42A5F5), Color(0xFF478ED1)],
      [Color(0xFFEC407A), Color(0xFFFF7043)],
      [Color(0xFFAB47BC), Color(0xFF7E57C2)],
    ];
    return gradients[index % gradients.length];
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      selectedIndex: 3,
      body: RefreshIndicator(
        onRefresh: _loadCourses,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(),

              const SizedBox(height: 16),

              _buildHighlightCard(), // 🔥 NEW SECTION

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              _buildTopRow(),

              const SizedBox(height: 16),

              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                _buildGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Hi, $studentName 👋",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(Icons.school, color: Colors.white, size: 32),
        ],
      ),
    );
  }

  // ================= HIGHLIGHT =================
  Widget _buildHighlightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7E5F), Color(0xFFFFC371)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "🔥 Boost your learning today!\nComplete 1 lesson to maintain your streak.",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ================= CONTINUE =================

  // ================= DROPDOWN =================
  Widget _buildTopRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Subjects",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        DropdownButton<ClassItem>(
          value: selectedClass,
          items: classes.map((cls) {
            return DropdownMenuItem(value: cls, child: Text(cls.name));
          }).toList(),
          onChanged: (cls) async {
            if (cls == null) return;

            setState(() {
              selectedClass = cls;
              _classId = cls.id;
            });

            await _saveClass(cls.id);
            await _loadCourses();
          },
        ),
      ],
    );
  }

  // ================= PREMIUM GRID =================
  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, i) {
        final c = courses[i];
        final gradient = getGradient(i);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LearnScreen(subject: c.name, courseId: c.id),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(getIcon(c.name), color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(
                  c.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================= MODELS =================
class Course {
  final int id;
  final String name;
  final double progress;
  final String lastTopic;
  final String lastSubject;

  Course({
    required this.id,
    required this.name,
    required this.progress,
    required this.lastTopic,
    required this.lastSubject,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? 0,
      name: json['title'] ?? 'Course',
      progress: 0.0,
      lastTopic: json['description'] ?? 'Start learning',
      lastSubject: json['category'] ?? 'General',
    );
  }
}

class ClassItem {
  final int id;
  final String name;

  ClassItem({required this.id, required this.name});

  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      id: json['id'],
      name: json['name'] ?? json['title'] ?? 'Class',
    );
  }
}
