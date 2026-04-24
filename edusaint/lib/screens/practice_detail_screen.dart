import 'dart:convert';
import 'package:edusaint/screens/start_quiz.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PracticeDetailScreen extends StatefulWidget {
  final int classId;
  final int courseId;

  const PracticeDetailScreen({
    super.key,
    required this.classId,
    required this.courseId,
  });

  @override
  State<PracticeDetailScreen> createState() => _PracticeDetailScreenState();
}

class _PracticeDetailScreenState extends State<PracticeDetailScreen> {
  List quizzes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchQuizList();
  }

  Future<void> fetchQuizList() async {
    try {
      final url = Uri.parse(
        "https://byte.edusaint.in/api/v1/classes/${widget.classId}/courses/${widget.courseId}/practice_quizzes",
      );

      final response = await http.get(url);

      debugPrint("QUIZ RESPONSE => ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true && data["quizzes"] != null) {
          quizzes = data["quizzes"];
        }
      }
    } catch (e) {
      debugPrint("Quiz fetch error: $e");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget quizCard(Map quiz, int index) {
    final title = quiz["name"] ?? "";
    final description = quiz["description"] ?? "";
    final difficulty = quiz["difficulty"] ?? "";
    final questions = quiz["questions_count"] ?? 0;
    final thumbnail = quiz["thumbnail_url"];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffE6C99F),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(.08),
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  difficulty.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xffFF8C00),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// Title
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],

          const SizedBox(height: 14),

          /// progress style line
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.7),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 16),

          /// info row
          Row(
            children: [
              infoItem(Icons.help_outline, "$questions Questions"),

              const SizedBox(width: 20),

              infoItem(Icons.bar_chart, difficulty),
            ],
          ),

          const SizedBox(height: 18),

          /// start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StartQuizScreen(
                      classId: widget.classId,
                      courseId: widget.courseId,
                      quizId: quiz["id"],
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 240, 240, 242),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Start Quiz"),
            ),
          ),
        ],
      ),
    );
  }

  Widget infoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String pageTitle = "";
    if (quizzes.isNotEmpty) {
      pageTitle = quizzes.first["course"] ?? "";
    }

    return Scaffold(
      backgroundColor: const Color(0xffF3F5F9),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,

        title: Text(
          pageTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : quizzes.isEmpty
          ? const Center(child: Text("No Quiz Available"))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: quizzes.length,
              itemBuilder: (context, index) {
                return quizCard(quizzes[index], index);
              },
            ),
    );
  }
}
