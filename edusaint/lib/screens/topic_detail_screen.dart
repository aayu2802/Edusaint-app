import 'dart:convert';
import 'package:edusaint/screens/video_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'chapter_detail_screen.dart';
import 'package:collection/collection.dart';

class TopicDetailScreen extends StatefulWidget {
  final int courseId;
  final int lessonId;
  final int topicId;
  final String chapter;
  final String subject;

  // 🔥 NEW (for continuous flow)
  final List<int> topicIds;
  final int currentTopicIndex;

  const TopicDetailScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.topicId,
    required this.chapter,
    required this.subject,

    // 🔥 NEW required fields
    required this.topicIds,
    required this.currentTopicIndex,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  String getText(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    if (value is List) {
      return value.map((e) => e is Map ? e['text'] ?? "" : "").join(" ");
    }
    if (value is Map) {
      return value['text'] ?? "";
    }
    return value.toString();
  }

  bool parseBool(dynamic value) {
    if (value == null) return false;
    final v = value.toString().toLowerCase().trim();
    return v == "true" || v == "1";
  }

  final Map<String, TextEditingController> blankControllers = {};
  Map<String, Map<String, String>> matchSelections = {};
  Map<String, List<String>> shuffledRightOptions = {};
  Map<String, List<Map<String, dynamic>>> sequenceUserOrder = {};

  Set<String> attemptedQuizIds = {};

  bool isLoading = true;
  bool hasError = false;
  List<Map<String, dynamic>> cards = [];
  int currentIndex = 0;

  // XP & Streak
  int totalXP = 0;
  int streak = 0;
  int maxStreak = 0;

  // Score
  int totalQuizzes = 0;
  int correctAnswers = 0;

  int currentQuizIndex = 0;
  Map<String, int> selectedOptionMap = {};
  Set<String> submittedQuizKeys = {};
  Map<String, bool> quizResultMap = {};
  void showCompletionAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.pop(context); // close animation
          showLessonSummary(); // open summary after animation
        });

        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.2),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: 110,
                        color: Colors.amber,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  "Topic Completed 🎉",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Great Job! Preparing next step...",
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }

  void saveProgress() {
    final box = Hive.box('topic_cache');

    final progressKey =
        "progress_${widget.courseId}_${widget.lessonId}_${widget.topicId}";

    box.put(progressKey, {
      'currentIndex': currentIndex,
      'currentQuizIndex': currentQuizIndex,
      'selectedOptionMap': selectedOptionMap,
      'submittedQuizKeys': submittedQuizKeys.toList(),
      'quizResultMap': quizResultMap,
      'blankAnswers': blankControllers.map(
        (k, v) => MapEntry(k.toString(), v.text),
      ),
      'matchSelections': matchSelections,
      'xp': totalXP,
      'streak': streak,
      'maxStreak': maxStreak,
      'correctAnswers': correctAnswers,
      'totalQuizzes': totalQuizzes,
    });
  }

  void restoreProgress() {
    final box = Hive.box('topic_cache');

    final progressKey =
        "progress_${widget.courseId}_${widget.lessonId}_${widget.topicId}";

    if (!box.containsKey(progressKey)) return;

    final data = box.get(progressKey);

    setState(() {
      currentIndex = data['currentIndex'] ?? 0;
      if (currentIndex >= cards.length) {
        currentIndex = cards.isEmpty ? 0 : cards.length - 1;
      }

      currentQuizIndex = data['currentQuizIndex'] ?? 0;

      selectedOptionMap = Map<String, int>.from(
        data['selectedOptionMap'] ?? {},
      );

      submittedQuizKeys = Set<String>.from(data['submittedQuizKeys'] ?? []);

      quizResultMap = Map<String, bool>.from(data['quizResultMap'] ?? {});

      matchSelections = Map<String, Map<String, String>>.from(
        (data['matchSelections'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), Map<String, String>.from(v)),
        ),
      );

      final blanks = Map<String, String>.from(data['blankAnswers'] ?? {});
      blanks.forEach((k, v) {
        blankControllers[k.toString()] = TextEditingController(text: v);

        totalXP = data['xp'] ?? 0;
        streak = data['streak'] ?? 0;
        maxStreak = data['maxStreak'] ?? 0;
        correctAnswers = data['correctAnswers'] ?? 0;
        totalQuizzes = data['totalQuizzes'] ?? 0;
      });
    });
  }

  @override
  void dispose() {
    for (final c in blankControllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await loadCards();
      restoreProgress();
    });
  }

  Future<void> loadCards() async {
    final box = Hive.box('topic_cache');

    final cacheKey =
        "cards_${widget.courseId}_${widget.lessonId}_${widget.topicId}";

    try {
      // 🔹 1️⃣ Load cache instantly
      if (box.containsKey(cacheKey)) {
        final cachedData = box.get(cacheKey) as List;

        cards = cachedData.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          isLoading = false;
          hasError = false;
        });

        debugPrint("Loaded cards from CACHE");
      }

      // 🔹 2️⃣ Fetch latest from API (background refresh)
      final url =
          "https://byte.edusaint.in/api/v1/courses/${widget.courseId}/lessons/${widget.lessonId}/topics/${widget.topicId}/cards";

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint("API failed → using cache");
        return;
      }

      final decoded = jsonDecode(res.body);
      final List rawCards = decoded['data'];

      final newCards =
          rawCards.map((e) => Map<String, dynamic>.from(e)).toList()..sort(
            (a, b) =>
                (a['display_order'] ?? 0).compareTo(b['display_order'] ?? 0),
          );

      // 🔹 3️⃣ Update only if changed
      if (cards.length != newCards.length) {
        debugPrint("New content detected → updating");

        await box.put(cacheKey, newCards);

        setState(() {
          cards = newCards;
          isLoading = false;
          hasError = false;
        });
      } else {
        debugPrint("Content unchanged");

        if (isLoading) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("LOAD ERROR => $e");

      // 🔹 4️⃣ If no cache show error
      if (!box.containsKey(cacheKey)) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    }
  }

  Widget quizFeedbackBox({required bool isCorrect, required String message}) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isCorrect
            ? LinearGradient(
                colors: [Colors.green.shade50, Colors.green.shade100],
              )
            : LinearGradient(colors: [Colors.red.shade50, Colors.red.shade100]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCorrect ? Colors.green : Colors.red),
        boxShadow: [
          BoxShadow(
            color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget premiumImageWidget({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
    );
  }

  Widget premiumTextBlock(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
                children: parseTaggedText(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget premiumRichTextBlock(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// LEFT DOT
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 7,
            width: 7,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(width: 12),

          /// TEXT CONTENT
          Expanded(
            child: RichText(
              textAlign: TextAlign.left,
              softWrap: true,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.75,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
                children: parseStyledText(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =======================================
  /// BOLD / ITALIC / UNDERLINE / HIGHLIGHT
  /// =======================================
  List<TextSpan> parseStyledText(String text) {
    List<TextSpan> spans = [];

    final RegExp exp = RegExp(
      r'(\*\*(.*?)\*\*)|(\*(.*?)\*)|(\[\[ul\]\](.*?)\[\[/ul\]\])|(\[\[hl\]\](.*?)\[\[/hl\]\])',
      dotAll: true,
    );

    int last = 0;

    for (final match in exp.allMatches(text)) {
      /// NORMAL TEXT BEFORE TAG
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }

      /// BOLD
      if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        );
      }
      /// ITALIC
      else if (match.group(4) != null) {
        spans.add(
          TextSpan(
            text: match.group(4),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      /// UNDERLINE
      else if (match.group(6) != null) {
        spans.add(
          TextSpan(
            text: match.group(6),
            style: const TextStyle(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      /// HIGHLIGHT
      else if (match.group(8) != null) {
        spans.add(
          TextSpan(
            text: match.group(8),
            style: TextStyle(
              backgroundColor: Colors.yellow.shade300,
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }

      last = match.end;
    }

    /// REMAINING TEXT
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return spans;
  }

  List<TextSpan> parseTaggedText(String text, {TextStyle? baseStyle}) {
    baseStyle ??= const TextStyle(
      fontSize: 15.5,
      height: 1.7,
      color: Color(0xFF1F2937),
    );

    final RegExp tagExp = RegExp(
      r'\[\[(\w+)\]\](.*?)\[\[/\1\]\]',
      dotAll: true,
    );

    List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final match in tagExp.allMatches(text)) {
      // Add normal text before tag
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final tag = match.group(1);
      final content = match.group(2) ?? "";

      TextStyle newStyle = baseStyle;

      switch (tag) {
        case 'b':
          newStyle = baseStyle.merge(
            const TextStyle(fontWeight: FontWeight.bold),
          );
          break;

        case 'i':
          newStyle = baseStyle.merge(
            const TextStyle(fontStyle: FontStyle.italic),
          );
          break;

        case 'u':
          newStyle = baseStyle.merge(
            const TextStyle(decoration: TextDecoration.underline),
          );
          break;

        case 'hl':
          newStyle = baseStyle.merge(
            const TextStyle(
              backgroundColor: Color(0xFFFFFF00), // bright yellow
              color: Colors.black, // better contrast
              fontWeight: FontWeight.w600,
            ),
          );
          break;

        case 'imp':
          newStyle = baseStyle.merge(
            const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          );
          break;
      }

      spans.add(
        TextSpan(
          style: newStyle,
          children: parseTaggedText(content, baseStyle: newStyle),
        ),
      );

      currentIndex = match.end;
    }

    // Remaining plain text
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
    }

    return spans;
  }

  Widget buildTaggedText(String text, {TextStyle? style}) {
    return RichText(
      text: TextSpan(children: parseTaggedText(text, baseStyle: style)),
    );
  }

  Widget buildDefinition(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Stack(
        children: [
          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6), // soft indigo background
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: Color(0xFF3949AB),
                    ),
                    SizedBox(width: 6),
                    Text(
                      "DEFINITION",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3949AB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                buildTaggedText(
                  text.trim(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Left Indigo Strip
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF3949AB),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTakeaway(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Stack(
        children: [
          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9), // soft green background
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: Color(0xFF2E7D32),
                    ),
                    SizedBox(width: 6),
                    Text(
                      "TAKEAWAY",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                buildTaggedText(
                  text.trim(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Left Green Strip
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildImportant(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Stack(
        children: [
          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFDEAEA), // soft red background
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Color(0xFFC62828),
                    ),
                    SizedBox(width: 6),
                    Text(
                      "IMPORTANT",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                buildTaggedText(
                  text.trim(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Left Red Strip
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFC62828),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMemoryTip(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Stack(
        children: [
          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF), // soft lavender background
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.psychology_rounded,
                      size: 20,
                      color: Color(0xFF7B1FA2),
                    ),
                    SizedBox(width: 6),
                    Text(
                      "MEMORY TIP",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B1FA2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                buildTaggedText(
                  text.trim(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Left Purple Strip
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildExample(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Stack(
        children: [
          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9), // soft green background
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      size: 20,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "EXAMPLE",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                buildTaggedText(
                  text.trim(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Left Vertical Strip
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDifference(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // soft grey background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1,
          style: BorderStyle.solid, // change to dashed manually if needed
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.compare_arrows_rounded,
                size: 20,
                color: Colors.black54,
              ),
              SizedBox(width: 6),
              Text(
                "DIFFERENCE",
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          buildTaggedText(
            text.trim(),
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.7,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeading(String text) {
    final clean = text.replaceAll(RegExp(r'\[\[/?h\]\]'), '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        clean,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildQuote(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_quote_rounded,
                size: 20,
                color: Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              Text(
                "Quote",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          buildTaggedText(
            cleaned,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBullet(String text) {
    final clean = text.replaceAll(RegExp(r'\[\[/?li\]\]'), '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• "),
          Expanded(child: Text(clean)),
        ],
      ),
    );
  }

  int _numberCounter = 1;

  Widget buildNumbered(String text) {
    final clean = text.replaceAll(RegExp(r'\[\[/?nli\]\]'), '');

    final widget = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${_numberCounter++}. "),
          Expanded(child: Text(clean)),
        ],
      ),
    );

    return widget;
  }

  Widget buildSubHeading(String text) {
    final clean = text.replaceAll(RegExp(r'\[\[/?sh\]\]'), '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        clean,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget premiumDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.blue.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.blue.withOpacity(0.15), blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.star_rounded, size: 14, color: Colors.blue),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.blue.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget conceptCard({
    required String title,
    required Widget child,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ===================== PREMIUM CARD UI =====================
  Widget premiumCard({
    required String title,
    required Widget child,
    Color? headerColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xfffbfcff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            spreadRadius: 1,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: headerColor ?? Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ===================== PREMIUM CONCEPT CARD =====================
  Widget renderConcept(Map<String, dynamic> card) {
    try {
      final raw = card['data_json'];
      if (raw == null) return const Text("No concept available");

      dynamic parsed;

      try {
        parsed = raw is String ? jsonDecode(raw) : raw;
      } catch (_) {
        parsed = {
          "blocks": [
            {"type": "text", "text": raw.toString()},
          ],
        };
      }

      final List blocks = parsed is Map && parsed['blocks'] is List
          ? parsed['blocks']
          : [
              {"type": "text", "text": raw.toString()},
            ];

      List<Widget> widgets = [];

      for (final b in blocks) {
        if (b == null) continue;

        switch ((b['type'] ?? 'text').toString()) {
          case 'image':
            final rawImg = b['url'] ?? b['image'];
            if (rawImg == null) break;

            final String img = rawImg.toString().trim();
            Widget imageWidget;

            if (img.startsWith("data:image")) {
              final base64Str = img.split(',').last;

              imageWidget = premiumImageWidget(
                child: Image.memory(
                  base64Decode(base64Str),
                  width: double.infinity,
                  fit: BoxFit.contain, // 🔥 stretch nahi karega
                ),
              );
            } else if (Uri.tryParse(img)?.isAbsolute == true) {
              imageWidget = premiumImageWidget(
                child: Image.network(
                  img,
                  width: double.infinity,
                  fit: BoxFit.contain, // 🔥 maintain ratio
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (c, o, s) => const Icon(
                    Icons.broken_image,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
              );
            } else {
              break;
            }

            widgets.add(imageWidget);
            widgets.add(const SizedBox(height: 16));
            break;

          case 'text':
            final text = b['text']?.toString() ?? '';
            if (text.isEmpty) break;

            final trimmed = text.trim();

            final blockTagExp = RegExp(
              r'\[\[(\w+)\]\](.*?)\[\[/\1\]\]',
              dotAll: true,
            );

            final matches = blockTagExp.allMatches(trimmed);

            if (matches.isNotEmpty) {
              int lastEnd = 0;

              for (final blockMatch in matches) {
                // Text before tag
                if (blockMatch.start > lastEnd) {
                  final plainText = trimmed
                      .substring(lastEnd, blockMatch.start)
                      .trim();

                  if (plainText.isNotEmpty) {
                    widgets.add(premiumRichTextBlock(plainText));
                  }
                }

                final tag = blockMatch.group(1);
                final content = blockMatch.group(2) ?? "";

                switch (tag) {
                  case 'h':
                    widgets.add(buildHeading(content));
                    break;

                  case 'sh':
                    widgets.add(buildSubHeading(content));
                    break;

                  case 'q':
                    widgets.add(buildQuote(content.trim()));
                    break;

                  case 'def':
                    widgets.add(buildDefinition(content));
                    break;

                  case 'take':
                    widgets.add(buildTakeaway(content));
                    break;

                  case 'imp':
                    widgets.add(buildImportant(content));
                    break;

                  case 'mem':
                    widgets.add(buildMemoryTip(content));
                    break;

                  case 'ex':
                    widgets.add(buildExample(content));
                    break;

                  case 'diff':
                    widgets.add(buildDifference(content));
                    break;

                  case 'li':
                    widgets.add(buildBullet(content));
                    break;

                  case 'nli':
                    widgets.add(buildNumbered(content));
                    break;

                  default:
                    widgets.add(premiumRichTextBlock(content));
                }

                lastEnd = blockMatch.end;
              }

              // Remaining text after last tag
              if (lastEnd < trimmed.length) {
                final remaining = trimmed.substring(lastEnd).trim();

                if (remaining.isNotEmpty) {
                  widgets.add(premiumRichTextBlock(remaining));
                }
              }
            } else {
              widgets.add(premiumRichTextBlock(trimmed));
            }
            break;

          case 'divider':
            widgets.add(premiumDivider());
            break;

          case 'keypoints':
            final points = b['points'] is List ? b['points'] : [];
            if (points.isNotEmpty) {
              widgets.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade50,
                        Colors.green.shade100.withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Key Points",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...points.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                height: 8,
                                width: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.toString(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: Color(0xFF064E3B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }
            break;

          default:
            debugPrint("Unknown block type: ${b['type']}");
        }
      }

      if (widgets.isEmpty) {
        return premiumRichTextBlock(raw.toString());
      }

      return premiumCard(
        title: "${card['topic_title'] ?? card['title'] ?? widget.chapter}",
        child: Column(children: widgets),
        headerColor: Colors.blue.shade50,
      );
    } catch (e) {
      debugPrint("CONCEPT ERROR => $e");
      return const Text("Invalid concept data");
    }
  }

  String buildQuestionText(Map<String, dynamic> q) {
    final questionObj = q['question'] is Map
        ? q['question'] as Map<String, dynamic>
        : q;

    if (questionObj['blocks'] is List) {
      final blocks = questionObj['blocks'] as List;

      return blocks
          .where((b) => b is Map && b['type'] == 'text')
          .map((b) => b['text']?.toString() ?? "")
          .join(" ");
    }

    return questionObj['text']?.toString() ?? "Question not available";
  }

  // ===================== PREMIUM QUIZ CARD =====================
  Widget renderQuiz(Map<String, dynamic> card) {
    try {
      final raw = card['data_json'];
      if (raw == null) return const Text("No quiz data");

      final parsed = raw is String ? jsonDecode(raw) : raw;
      final List questions = parsed['questions'] is List
          ? parsed['questions']
          : [];

      if (questions.isEmpty) return const Text("No quiz questions");

      final int quizIndex = currentQuizIndex.clamp(0, questions.length - 1);

      final Map<String, dynamic> q = Map<String, dynamic>.from(
        questions[quizIndex],
      );

      final Map<String, dynamic> questionObj = q['question'] is Map
          ? Map<String, dynamic>.from(q['question'])
          : q;

      String questionText;

      if (q['type'] == 'fib' && q['fibData'] != null) {
        questionText = q['fibData']['question'] ?? "";
      } else {
        questionText = buildQuestionText(q);
      }

      final String rawType =
          q['type']?.toString().toLowerCase().trim() ?? 'mcq';

      final bool hasBlankBlock =
          questionObj['blocks'] is List &&
          (questionObj['blocks'] as List).any(
            (b) =>
                b is Map &&
                (b['type'] == 'blank' ||
                    b['type'] == 'fill_blank' ||
                    b['type'] == 'input'),
          );

      final String questionType = rawType == 'sequence'
          ? 'sequence'
          : hasBlankBlock ||
                rawType == 'fill_in_the_blank' ||
                rawType == 'fillblank' ||
                rawType == 'fib'
          ? 'fill_blank'
          : (rawType == 'match' || rawType == 'match_the_following')
          ? 'match'
          : 'mcq';

      final List options = q['options'] is List
          ? q['options']
          : (questionObj['options'] is List ? questionObj['options'] : []);

      final String quizKey = getQuizKey(currentIndex, quizIndex);

      final bool submitted = submittedQuizKeys.contains(quizKey);

      final bool selectedIsCorrect = quizResultMap[quizKey] ?? false;

      return premiumCard(
        title:
            "${card['topic_title'] ?? card['title']} • Quiz ${quizIndex + 1}/${questions.length}",
        headerColor: Colors.orange.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ===== QUESTION BLOCKS RENDER =====
            if (questionObj['blocks'] is List)
              ...((questionObj['blocks'] as List).map((b) {
                if (b is! Map) return const SizedBox();

                switch (b['type']) {
                  case 'text':
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        b['text'] ?? "",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );

                    return const SizedBox();

                  case 'image':
                    final rawImg = b['url'] ?? b['image'];
                    if (rawImg == null) return const SizedBox();

                    final String img = rawImg.toString().trim();

                    if (img.startsWith("data:image")) {
                      final base64Str = img.split(',').last;
                      return premiumImageWidget(
                        child: Image.memory(
                          base64Decode(base64Str),
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      );
                    } else if (Uri.tryParse(img)?.isAbsolute == true) {
                      return premiumImageWidget(
                        child: Image.network(
                          img,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          errorBuilder: (c, o, s) => const Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    return const SizedBox();

                  default:
                    return const SizedBox();
                }
              }).toList())
            else
              Text(
                questionText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 16),
            if (q['questionImageUrl'] != null &&
                q['questionImageUrl'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: premiumImageWidget(
                  child: Image.network(
                    "https://byte.edusaint.in${q['questionImageUrl']}",
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (c, o, s) => const Icon(
                      Icons.broken_image,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

            /// ================= FILL BLANK =================
            if (questionType == 'fill_blank')
              TextField(
                controller: blankControllers.putIfAbsent(
                  quizKey,
                  () => TextEditingController(),
                ),
                enabled: !submitted,
                onChanged: (_) => saveProgress(),
                decoration: InputDecoration(
                  hintText: "Type your answer here",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

            /// ================= MCQ =================
            if (questionType == 'mcq')
              ...List.generate(options.length, (index) {
                final option = options[index];

                bool isCorrect = false;

                if (q['correctIndex'] != null) {
                  isCorrect = index == q['correctIndex'];
                } else {
                  final correctAnswer = (q['answer'] ?? questionObj['answer'])
                      ?.toString()
                      .trim();

                  final selectedText = option['text']?.toString().trim();

                  isCorrect = selectedText == correctAnswer;
                }

                final int selectedIndex = selectedOptionMap[quizKey] ?? -1;

                Color bg = Colors.white;
                Color border = Colors.grey.shade300;
                IconData icon = Icons.radio_button_off;

                if (submitted) {
                  if (isCorrect) {
                    bg = Colors.green.shade50;
                    border = Colors.green;
                    icon = Icons.check_circle;
                  }

                  if (!isCorrect && index == selectedIndex) {
                    bg = Colors.red.shade50;
                    border = Colors.red;
                    icon = Icons.cancel;
                  }
                } else if (index == selectedIndex) {
                  bg = Colors.blue.shade50;
                  border = Colors.blue;
                  icon = Icons.radio_button_checked;
                }

                return GestureDetector(
                  onTap: submitted
                      ? null
                      : () {
                          setState(() {
                            selectedOptionMap[quizKey] = index;
                            saveProgress();
                          });
                        },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: border),
                        const SizedBox(width: 12),
                        Expanded(child: Text(option['text'] ?? '')),
                      ],
                    ),
                  ),
                );
              }),

            /// ================= MATCH =================
            if (questionType == 'match') ..._buildMatchUI(q, quizKey),

            const SizedBox(height: 12),

            /// ================= SEQUENCE =================
            if (questionType == 'sequence') ..._buildSequenceUI(q, quizKey),

            /// ================= SUBMIT =================
            if (!submitted)
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    bool finalIsCorrect = false;

                    if (questionType == 'fill_blank') {
                      final user = blankControllers[quizKey]?.text
                          .trim()
                          .toLowerCase();

                      if (user == null || user.isEmpty) return;

                      List<String> correctAnswers = [];

                      if (q['fibData'] != null &&
                          q['fibData']['correctAnswers'] is List) {
                        correctAnswers =
                            List<String>.from(q['fibData']['correctAnswers'])
                                .map((e) => e.toString().trim().toLowerCase())
                                .toList();
                      }

                      finalIsCorrect = correctAnswers.contains(user);
                    }

                    if (questionType == 'mcq') {
                      final selectedIndex = selectedOptionMap[quizKey] ?? -1;
                      if (selectedIndex == -1) return;

                      final correctIndex = q['correctIndex'];

                      if (correctIndex != null) {
                        finalIsCorrect = selectedIndex == correctIndex;
                      } else {
                        // fallback: check answer text if exists
                        final correctAnswer =
                            (q['answer'] ?? questionObj['answer'])
                                ?.toString()
                                .trim();

                        final selectedText = options[selectedIndex]['text']
                            ?.toString()
                            .trim();

                        finalIsCorrect = selectedText == correctAnswer;
                      }
                    }

                    if (questionType == 'match') {
                      final matchData = q['matchData'];
                      final List pairs = matchData['pairs'];

                      final Map<String, String> correctMap = {
                        for (var p in pairs)
                          p['left'].toString(): p['right'].toString(),
                      };

                      final userMap = matchSelections[quizKey] ?? {};

                      finalIsCorrect = true;

                      for (var key in correctMap.keys) {
                        if (userMap[key] != correctMap[key]) {
                          finalIsCorrect = false;
                          break;
                        }
                      }
                    }
                    if (questionType == 'sequence') {
                      final sequenceData = q['sequenceData'];

                      if (sequenceData == null || sequenceData['items'] == null)
                        return;

                      final List correctItems = (sequenceData['items'] as List)
                          .map((e) => Map<String, dynamic>.from(e as Map))
                          .toList();

                      // sort by correct order
                      correctItems.sort(
                        (a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0),
                      );

                      final userList = sequenceUserOrder[quizKey];

                      if (userList == null) return;

                      finalIsCorrect = true;

                      for (int i = 0; i < correctItems.length; i++) {
                        if (userList[i]['id'] != correctItems[i]['id']) {
                          finalIsCorrect = false;
                          break;
                        }
                      }
                    }

                    setState(() {
                      final alreadySubmitted = submittedQuizKeys.contains(
                        quizKey,
                      );

                      if (!alreadySubmitted) {
                        totalQuizzes++;
                      }

                      submittedQuizKeys.add(quizKey);
                      quizResultMap[quizKey] = finalIsCorrect;

                      if (finalIsCorrect) {
                        correctAnswers++;
                        totalXP += 10;
                        streak++;
                        if (streak > maxStreak) maxStreak = streak;
                      } else {
                        streak = 0;
                      }

                      saveProgress();
                    });

                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (currentQuizIndex < questions.length - 1) {
                        setState(() {
                          currentQuizIndex++;
                        });
                      }
                    });
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Submit Answer",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            /// ================= FEEDBACK =================
            if (submitted)
              quizFeedbackBox(
                isCorrect: selectedIsCorrect,
                message: selectedIsCorrect
                    ? (q['generalCorrectFb'] ?? "Correct! +10 XP 🔥")
                    : (q['generalIncorrectFb'] ??
                          "Wrong answer. Streak reset."),
              ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint("QUIZ ERROR => $e");
      debugPrint("STACK => $stack");
      return const Text("Invalid quiz data");
    }
  }

  List<Widget> _buildMatchUI(Map<String, dynamic> q, String quizKey) {
    /// FULL QUESTION JSON PRINT
    debugPrint("========= MATCH QUESTION =========");
    debugPrint(const JsonEncoder.withIndent('  ').convert(q));
    debugPrint("=================================");

    final matchData = q['matchData'];

    if (matchData == null || matchData['pairs'] == null) {
      return [const Text("Invalid match data")];
    }

    final List pairs = matchData['pairs'];

    /// LEFT ITEMS
    final List<String> leftItems = pairs
        .map((e) => e['left'].toString())
        .toList();

    /// RIGHT ITEMS
    final List<String> rightItems = pairs
        .map((e) => e['right'].toString())
        .toList();

    /// RANDOMIZE IF TRUE
    final bool randomize = matchData['randomize'] == true;

    shuffledRightOptions.putIfAbsent(quizKey, () {
      final temp = List<String>.from(rightItems);

      if (randomize) {
        temp.shuffle();
      }

      return temp;
    });

    final List<String> dropdownItems = shuffledRightOptions[quizKey]!;

    /// CORRECT ANSWER MAP
    final Map<String, String> correctMap = {
      for (var p in pairs) p['left'].toString(): p['right'].toString(),
    };

    /// USER SELECTION STORAGE
    matchSelections.putIfAbsent(quizKey, () => {});

    final bool submitted = submittedQuizKeys.contains(quizKey);

    return [
      /// QUESTION TITLE
      Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Text(
          q['text'] ?? "Match the following",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),

      ...leftItems.map((leftText) {
        final selected = matchSelections[quizKey]![leftText];

        final correct = correctMap[leftText];

        final bool isCorrect =
            submitted && selected != null && selected == correct;

        final bool isWrong =
            submitted && selected != null && selected != correct;

        Color borderColor = Colors.grey.shade300;
        Color bgColor = Colors.white;
        IconData? icon;

        if (isCorrect) {
          borderColor = Colors.green;
          bgColor = Colors.green.shade50;
          icon = Icons.check_circle;
        } else if (isWrong) {
          borderColor = Colors.red;
          bgColor = Colors.red.shade50;
          icon = Icons.cancel;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.3),
          ),
          child: Row(
            children: [
              /// LEFT TEXT
              Expanded(
                flex: 4,
                child: Text(
                  leftText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              /// DROPDOWN
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: dropdownItems.contains(selected) ? selected : null,
                  decoration: InputDecoration(
                    hintText: "Select Match",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: dropdownItems.map((item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                  onChanged: submitted
                      ? null
                      : (val) {
                          setState(() {
                            matchSelections[quizKey]![leftText] = val!;
                          });
                        },
                ),
              ),

              /// RESULT ICON
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(icon, color: borderColor),
                ),
            ],
          ),
        );
      }).toList(),
    ];
  }

  List<Widget> _buildSequenceUI(Map<String, dynamic> q, String quizKey) {
    final sequenceData = q['sequenceData'];

    if (sequenceData == null || sequenceData['items'] == null) {
      return [const Text("Invalid sequence data")];
    }

    final List itemsRaw = sequenceData['items'] ?? [];

    final List<Map<String, dynamic>> items = itemsRaw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // shuffle only first time
    sequenceUserOrder.putIfAbsent(quizKey, () {
      final temp = List<Map<String, dynamic>>.from(items);
      if (sequenceData['randomize'] == true) {
        temp.shuffle();
      }
      return temp;
    });

    final userList = sequenceUserOrder[quizKey]!;

    final bool submitted = submittedQuizKeys.contains(quizKey);

    return [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: submitted
            ? (_, __) {}
            : (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;

                final item = userList.removeAt(oldIndex);
                userList.insert(newIndex, item);

                setState(() {});
              },
        children: [
          for (int i = 0; i < userList.length; i++)
            Container(
              key: ValueKey(userList[i]['id']),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                userList[i]['text'] ?? "",
                style: const TextStyle(fontSize: 16),
              ),
            ),
        ],
      ),
    ];
  }

  String getQuizKey(int cardIndex, int quizIndex) {
    return "${cardIndex}_$quizIndex";
  }

  void nextCard() {
    final card = cards[currentIndex];

    if (card['card_type'] == 'quiz') {
      final quizKey = getQuizKey(currentIndex, currentQuizIndex);

      if (!submittedQuizKeys.contains(quizKey)) {
        return;
      }
    }

    if (currentIndex < cards.length - 1) {
      setState(() {
        currentIndex++;
        currentQuizIndex = 0;
      });

      saveProgress();
    } else {
      Hive.box('topic_cache').delete(
        "progress_${widget.courseId}_${widget.lessonId}_${widget.topicId}",
      );

      showCompletionAnimation();
    }
  }

  void previousCard() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        currentQuizIndex = 0;
      });

      saveProgress();
    }
  }

  void showLessonSummary() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final accuracy = totalQuizzes == 0
            ? 0
            : ((correctAnswers / totalQuizzes) * 100).round();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Lesson Summary 📊",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              summaryRow("Total Quizzes", totalQuizzes.toString()),
              summaryRow("Correct Answers", correctAnswers.toString()),
              summaryRow("Accuracy", "$accuracy%"),
              summaryRow("XP Earned", "$totalXP XP"),
              summaryRow("Max Streak", "🔥 $maxStreak"),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);

                  // 👉 Check if next topic exists in list
                  if (widget.currentTopicIndex < widget.topicIds.length - 1) {
                    final nextIndex = widget.currentTopicIndex + 1;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopicDetailScreen(
                          courseId: widget.courseId,
                          lessonId: widget.lessonId,
                          topicId:
                              widget.topicIds[nextIndex], // ✅ next topic ID
                          topicIds: widget.topicIds, // 🔥 full list pass
                          currentTopicIndex: nextIndex, // 🔥 update index
                          chapter: widget.chapter,
                          subject: widget.subject,
                        ),
                      ),
                    );
                  } else {
                    // ✅ Last topic → go back to chapter
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChapterDetailScreen(
                          subject: widget.subject,
                          chapter: widget.chapter,
                          lessonId: widget.lessonId,
                          courseId: widget.courseId,
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  widget.currentTopicIndex < widget.topicIds.length - 1
                      ? "Next Topic"
                      : "Finish Chapter",
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (hasError || cards.isEmpty) {
      return const Scaffold(body: Center(child: Text("No cards available")));
    }

    if (currentIndex >= cards.length) {
      currentIndex = cards.length - 1;
    }

    final card = cards[currentIndex];
    if (card['card_type'] == 'video') {
      return VideoCardWidget(card: card);
    }
    final int cardId = card['id'];

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),

      /// 🧭 AppBar
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,

        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),

        flexibleSpace: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
            gradient: const LinearGradient(
              colors: [Color(0xffffffff), Color(0xfff7f9ff), Color(0xffeef4ff)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),

        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.black87,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card['card_type'] == 'quiz' ? "Quick Quiz" : "Concept",
              style: const TextStyle(
                color: Color(0xff111827),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.chapter,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff4F46E5), Color(0xff6366F1)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff4F46E5).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                "${currentIndex + 1}/${cards.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),

      /// 🧩 Body
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F5FF), Color(0xFFE8EEFF), Color(0xFFF9FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),

                /// 📊 Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (currentIndex + 1) / cards.length,
                    minHeight: 4,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4A6CF7)),
                  ),
                ),

                const SizedBox(height: 16),

                /// 📦 Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      final offsetAnim = Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation);

                      return SlideTransition(
                        position: offsetAnim,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: SingleChildScrollView(
                      key: ValueKey("$cardId-$currentQuizIndex"),

                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          if (card['card_type'] == 'concept')
                            renderConcept(card),

                          if (card['card_type'] == 'quiz') renderQuiz(card),
                        ],
                      ),
                    ),
                  ),
                ),

                /// ⏮️ ⏭️ Navigation
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: previousCard,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text(
                          "Previous",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            (card['card_type'] == 'quiz' &&
                                !submittedQuizKeys.contains(
                                  getQuizKey(currentIndex, currentQuizIndex),
                                ))
                            ? null
                            : nextCard,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          currentIndex == cards.length - 1
                              ? "Finish Lesson"
                              : "Continue",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
