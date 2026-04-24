import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'topic_detail_screen.dart';

class ChapterDetailScreen extends StatefulWidget {
  final String subject;
  final String chapter;
  final int lessonId;
  final int courseId;

  const ChapterDetailScreen({
    super.key,
    required this.subject,
    required this.chapter,
    required this.lessonId,
    required this.courseId,
  });

  @override
  State<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends State<ChapterDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;

  bool isLoading = true;
  List<Map<String, dynamic>> topics = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    fetchTopics();
  }

  void _initAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _color1 = ColorTween(
      begin: const Color(0xFF5EFCE8),
      end: const Color(0xFF736EFE),
    ).animate(_controller);

    _color2 = ColorTween(
      begin: const Color(0xFF736EFE),
      end: const Color(0xFF5EFCE8),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchTopics() async {
    try {
      final url =
          'https://byte.edusaint.in/api/v1/courses/${widget.courseId}/lessons/${widget.lessonId}/topics';

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        final List rawList = decoded['topics'] is List ? decoded['topics'] : [];

        rawList.sort((a, b) {
          final aDate = DateTime.tryParse(a['created_at'] ?? '');
          final bDate = DateTime.tryParse(b['created_at'] ?? '');
          return (aDate ?? DateTime(0)).compareTo(bDate ?? DateTime(0));
        });

        if (!mounted) return;

        setState(() {
          topics = rawList.whereType<Map<String, dynamic>>().toList();
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("ERROR: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    // 🔥 Extract topic IDs list once
    final List<int> topicIds = topics.map((e) => e['id'] as int).toList();

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final color1 = _color1.value ?? const Color(0xFF5EFCE8);
            final color2 = _color2.value ?? const Color(0xFF736EFE);

            return Column(
              children: [
                /// HEADER
                Container(
                  width: double.infinity,
                  height: height * 0.22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color1, color2]),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.05,
                    vertical: height * 0.04,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.chapter,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: width * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// BODY
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : topics.isEmpty
                      ? const Center(child: Text("No topics available"))
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: width * 0.05,
                          ),
                          itemCount: topics.length,
                          itemBuilder: (context, index) {
                            final topic = topics[index];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TopicDetailScreen(
                                      courseId: widget.courseId,
                                      lessonId: widget.lessonId,
                                      topicId: topic['id'],

                                      // 🔥 NEW FLOW
                                      topicIds: topicIds,
                                      currentTopicIndex: index,

                                      chapter: widget.chapter,
                                      subject: widget.subject,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: EdgeInsets.all(height * 0.02),
                                decoration: BoxDecoration(
                                  color: index.isEven
                                      ? const Color(0xFFDFF6FF)
                                      : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                      color: Colors.black12,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Colors.white,
                                      child: Icon(Icons.book_rounded),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        topic['title'] ?? 'Topic',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
