// ignore_for_file: collection_methods_unrelated_type

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StartQuizScreen extends StatefulWidget {
  final int classId;
  final int courseId;
  final int quizId;

  const StartQuizScreen({
    super.key,
    required this.classId,
    required this.courseId,
    required this.quizId,
  });

  @override
  State<StartQuizScreen> createState() => _StartQuizScreenState();
}

class _StartQuizScreenState extends State<StartQuizScreen> {
  bool isLoading = true;

  Map<String, dynamic>? quiz;
  List questions = [];

  int currentQuestion = 0;
  Map<int, dynamic> answers = {};

  bool showResult = false;

  int secondsRemaining = 0;
  Timer? timer;

  final TextEditingController fibController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchQuiz();
  }

  // ================= FETCH =================
  Future<void> fetchQuiz() async {
    try {
      final url = Uri.parse(
        "https://byte.edusaint.in/api/v1/classes/${widget.classId}/courses/${widget.courseId}/practice_quizzes/${widget.quizId}",
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          quiz = data["quiz"];
          questions = quiz?["questions_json"]?["questions"] ?? [];

          secondsRemaining = (quiz?["time_limit"] ?? 60) * 60;

          startTimer();
        }
      }
    } catch (e) {
      debugPrint("Quiz Error: $e");
    }

    setState(() => isLoading = false);
  }

  // ================= TIMER =================
  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining <= 0) {
        finishQuiz();
      } else {
        setState(() => secondsRemaining--);
      }
    });
  }

  String formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // ================= ACTIONS =================
  void submitAnswer() {
    setState(() => showResult = true);
  }

  void nextQuestion() {
    setState(() => showResult = false);

    if (currentQuestion < questions.length - 1) {
      currentQuestion++;
    } else {
      finishQuiz();
    }
  }

  void previousQuestion() {
    setState(() => showResult = false);

    if (currentQuestion > 0) {
      currentQuestion--;
    }
  }

  // ================= FINISH =================
  void finishQuiz() {
    timer?.cancel();

    int correct = 0;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];

      if (q["type"] == "fib") {
        final correctAnswers = q["fibData"]["correctAnswers"];

        if (answers[i] != null &&
            correctAnswers.contains(answers[i].toString().toLowerCase())) {
          correct++;
        }
      } else if (q["type"] == "match") {
        final pairs = q["matchData"]["pairs"];

        bool allCorrect = true;

        for (int j = 0; j < pairs.length; j++) {
          final selected = answers["$i-$j"];
          final correctRight = pairs[j]["right"];

          if (selected != correctRight) {
            allCorrect = false;
          }
        }

        if (allCorrect) correct++;
      } else {
        final correctIndex = q["correctIndex"];
        if (answers[i] == correctIndex) correct++;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          total: questions.length,
          correct: correct,
          attempted: answers.length,
        ),
      ),
    );
  }

  // ================= OPTIONS =================
  Widget buildOptions(Map question) {
    final options = question["options"] ?? [];
    final correctIndex = question["correctIndex"];

    return Column(
      children: List.generate(options.length, (index) {
        final isSelected = answers[currentQuestion] == index;
        final isCorrect = index == correctIndex;

        Color border = Colors.grey.shade300;
        Color bg = Colors.white;

        if (showResult) {
          if (isCorrect) {
            border = Colors.green;
            bg = Colors.green.withOpacity(0.15);
          } else if (isSelected) {
            border = Colors.red;
            bg = Colors.red.withOpacity(0.15);
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
            color: bg,
          ),
          child: ListTile(
            leading: showResult && isCorrect
                ? const Icon(Icons.check_circle, color: Colors.green)
                : Radio(
                    value: index,
                    groupValue: answers[currentQuestion],
                    onChanged: showResult
                        ? null
                        : (v) {
                            setState(() {
                              answers[currentQuestion] = index;
                            });
                          },
                  ),
            title: Text(options[index]["text"]),
          ),
        );
      }),
    );
  }

  // ================= FIB =================
  Widget buildFIB(Map question) {
    final fibData = question["fibData"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fibData["question"], style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        TextField(
          controller: fibController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Enter your answer",
          ),
          onChanged: (v) => answers[currentQuestion] = v,
        ),
      ],
    );
  }

  // ================= QUESTION =================
  Widget questionCard(Map question) {
    final explanation = question["explanation"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Question ${currentQuestion + 1}/${questions.length}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        Text(question["text"] ?? "", style: const TextStyle(fontSize: 18)),

        const SizedBox(height: 20),

        if (question["type"] == "fib")
          buildFIB(question)
        else
          buildOptions(question),

        const SizedBox(height: 20),

        /// ✅ FEEDBACK UI
        if (showResult)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    explanation ?? "Correct answer! Great job 🎉",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = (currentQuestion + 1) / questions.length;
    final question = questions[currentQuestion];

    return Scaffold(
      appBar: AppBar(
        title: Text(quiz?["name"] ?? "Quiz"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                formatTime(secondsRemaining),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, minHeight: 8),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(child: questionCard(question)),
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: previousQuestion,
                    child: const Text("Previous"),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (!showResult) {
                        submitAnswer();
                      } else {
                        nextQuestion();
                      }
                    },
                    child: Text(
                      !showResult
                          ? "Submit Answer"
                          : (currentQuestion == questions.length - 1
                                ? "Finish Lesson"
                                : "Next"),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================= RESULT =================
class QuizResultScreen extends StatelessWidget {
  final int total;
  final int correct;
  final int attempted;

  const QuizResultScreen({
    super.key,
    required this.total,
    required this.correct,
    required this.attempted,
  });

  @override
  Widget build(BuildContext context) {
    final score = (correct / total) * 100;

    return Scaffold(
      appBar: AppBar(title: const Text("Quiz Result")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 90, color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              "${score.toStringAsFixed(0)}%",
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text("Total: $total"),
            Text("Attempted: $attempted"),
            Text("Correct: $correct"),
            Text("Wrong: ${attempted - correct}"),
          ],
        ),
      ),
    );
  }
}
