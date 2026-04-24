import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'MainScaffold.dart';
import 'chapter_detail_screen.dart';

class LearnScreen extends StatefulWidget {
  final int courseId;
  final String subject;

  const LearnScreen({
    super.key,
    this.courseId = 4,
    this.subject = "Mathematics",
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<Map<String, dynamic>> chapters = [];
  bool isLoading = true;

  String get apiUrl =>
      'https://byte.edusaint.in/api/v1/courses/${widget.courseId}/lessons';

  // ---------------- OVERALL PROGRESS ----------------
  double get overallProgress {
    if (chapters.isEmpty) return 0.0;

    double total = 0;
    for (var chapter in chapters) {
      total += (chapter['progress'] ?? 0.0);
    }

    return total / chapters.length;
  }

  @override
  void initState() {
    super.initState();
    fetchLessons();
  }

  // ---------------- API CALL (FIXED) ----------------
  Future<void> fetchLessons() async {
    try {
      final res = await http.get(Uri.parse(apiUrl));

      if (res.statusCode != 200) {
        throw Exception("API Failed: ${res.statusCode}");
      }

      final decoded = jsonDecode(res.body);

      // ✅ SAFE DATA EXTRACTION
      final List data = (decoded != null && decoded['data'] is List)
          ? decoded['data']
          : [];

      final parsed = data.map<Map<String, dynamic>>((item) {
        final int id = int.tryParse(item['id']?.toString() ?? "0") ?? 0;

        final String title =
            (item['title'] ?? item['topic_name'] ?? 'Lesson $id').toString();

        double progress = 0.0;

        final rawProgress = item['progress'];

        // ✅ SAFE PROGRESS PARSING
        if (rawProgress is num) {
          progress = rawProgress.toDouble();
        } else if (rawProgress is String) {
          progress = double.tryParse(rawProgress) ?? 0.0;
        } else if (item['completion_percentage'] != null) {
          final cp = item['completion_percentage'];
          if (cp is num) {
            progress = (cp / 100).toDouble();
          } else if (cp is String) {
            progress = (double.tryParse(cp) ?? 0.0) / 100;
          }
        } else if (item['is_completed'] == true) {
          progress = 1.0;
        }

        progress = progress.clamp(0.0, 1.0);

        return {
          "id": id,
          "title": title,
          "progress": progress,
          "isCompleted": progress >= 1.0,
          "description": item['description'] ?? '',
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        chapters = parsed;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Lessons Error: $e");

      if (!mounted) return;

      setState(() {
        chapters = [];
        isLoading = false;
      });
    }
  }

  // ---------------- NAVIGATION ----------------
  void onChapterTap(int index) async {
    if (index >= chapters.length) return; // ✅ safety

    final chapter = chapters[index];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterDetailScreen(
          subject: widget.subject,
          chapter: chapter['title'],
          lessonId: chapter['id'],
          courseId: widget.courseId,
        ),
      ),
    );

    // ✅ LOCAL UPDATE SAFE
    if (result == true && mounted && index < chapters.length) {
      setState(() {
        chapters[index]['progress'] = 1.0;
        chapters[index]['isCompleted'] = true;
      });
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return MainScaffold(
      selectedIndex: 1,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ---------------- HEADER ----------------
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * .05,
                    vertical: h * .015,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Icon(Icons.arrow_back_ios_new),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          widget.subject,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: w * .052,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // PROGRESS BADGE
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: w * .04,
                          vertical: h * .008,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade200,
                              Colors.blue.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          "${(overallProgress * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------------- LIST ----------------
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: w * .05),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];

                      final bool isCompleted = chapter['isCompleted'] ?? false;
                      final double progress = (chapter['progress'] ?? 0.0)
                          .toDouble();

                      return GestureDetector(
                        onTap: () => onChapterTap(index),
                        child: Container(
                          margin: EdgeInsets.only(bottom: h * .025),
                          padding: EdgeInsets.all(w * .05),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: isCompleted
                                  ? [
                                      Colors.green.shade50,
                                      Colors.green.shade100,
                                    ]
                                  : [
                                      Colors.orange.shade50,
                                      Colors.orange.shade100,
                                    ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // TOP ROW
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Chapter ${index + 1}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    isCompleted ? "Completed" : "In Progress",
                                    style: TextStyle(
                                      color: isCompleted
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              Text(
                                chapter['title'] ?? "",
                                style: TextStyle(
                                  fontSize: w * .045,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // PROGRESS BAR
                              LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.white,
                                valueColor: AlwaysStoppedAnimation(
                                  isCompleted ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
