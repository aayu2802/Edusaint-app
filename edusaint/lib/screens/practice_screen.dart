import 'dart:convert';
import 'dart:ui';
import 'package:edusaint/screens/practice_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'MainScaffold.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int? _classId;
  String? _authToken;

  bool isLoading = true;

  List<Course> subjects = [];
  List<ClassItem> classes = [];
  ClassItem? selectedClass;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ================= INIT =================
  Future<void> _initialize() async {
    await _loadToken();
    await _loadSavedClass();
    await _loadClasses();
    await _loadSubjects();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString("token");
  }

  Future<void> _loadSavedClass() async {
    final prefs = await SharedPreferences.getInstance();
    _classId = prefs.getInt("selected_class_id") ?? 6;
  }

  Future<void> _saveClass(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("selected_class_id", id);
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

  // ================= SUBJECTS =================
  Future<void> _loadSubjects() async {
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

        subjects = data.map((e) => Course.fromJson(e)).toList();
      } else {
        subjects = [];
      }
    } catch (e) {
      subjects = [];
    }

    setState(() => isLoading = false);
  }

  // ================= ICON =================
  IconData getSubjectIcon(String name) {
    final lower = name.toLowerCase();

    if (lower.contains("math")) return Icons.calculate;
    if (lower.contains("science")) return Icons.science;
    if (lower.contains("english")) return Icons.menu_book;
    if (lower.contains("social")) return Icons.public;
    if (lower.contains("computer")) return Icons.computer;
    if (lower.contains("physics")) return Icons.bolt;
    if (lower.contains("chemistry")) return Icons.science;
    if (lower.contains("biology")) return Icons.biotech;

    return Icons.book;
  }

  // ================= GRADIENT =================
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
      selectedIndex: 2,
      body: RefreshIndicator(
        onRefresh: _loadSubjects,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            int gridCount = 3;
            if (width < 360) gridCount = 2;
            if (width > 600) gridCount = 4;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(width * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 TOP PREMIUM CARD
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(width * 0.05),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7E5F), Color(0xFFFFC371)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "🔥 Practice daily & boost your score!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: width * 0.06),

                  // 💎 GLASS CARD
                  SizedBox(height: width * 0.07),

                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "All Subjects",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<ClassItem>(
                        value: selectedClass,
                        items: classes.map((cls) {
                          return DropdownMenuItem(
                            value: cls,
                            child: Text(cls.name),
                          );
                        }).toList(),
                        onChanged: (cls) async {
                          if (cls == null) return;

                          setState(() {
                            selectedClass = cls;
                            _classId = cls.id;
                          });

                          await _saveClass(cls.id);
                          await _loadSubjects();
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: width * 0.05),

                  // GRID
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: subjects.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCount,
                        crossAxisSpacing: width * 0.04,
                        mainAxisSpacing: width * 0.04,
                      ),
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        final gradient = getGradient(index);

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PracticeDetailScreen(
                                  classId: _classId!,
                                  courseId: subject.id,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradient),
                              borderRadius: BorderRadius.circular(20),
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
                                Icon(
                                  getSubjectIcon(subject.name),
                                  size: 28,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  subject.name,
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
                    ),

                  SizedBox(height: width * 0.08),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= GLASS =================
  Widget _glassCard(double width, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(width * 0.04),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ================= MODELS =================
class Course {
  final int id;
  final String name;

  Course({required this.id, required this.name});

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(id: json['id'] ?? 0, name: json['title'] ?? 'Subject');
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ClassItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
