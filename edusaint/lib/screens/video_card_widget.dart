import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class VideoCardWidget extends StatefulWidget {
  final Map<String, dynamic> card;

  const VideoCardWidget({super.key, required this.card});

  @override
  State<VideoCardWidget> createState() => _VideoCardWidgetState();
}

class _VideoCardWidgetState extends State<VideoCardWidget> {
  VideoPlayerController? _controller;
  Timer? overlayTimer;

  bool isReady = false;
  bool isPlaying = false;
  bool isMuted = false;
  bool hasError = false;
  bool showOverlay = true;
  bool videoEnded = false;

  double speed = 1.0;

  String errorText = "";
  String title = "Learning Video";
  String subtitle = "Watch carefully and answer quizzes";

  List interactions = [];
  final Set<String> triggered = {};

  @override
  void initState() {
    super.initState();
    initVideo();
  }

  // ===================================================
  // INIT VIDEO
  // ===================================================
  Future<void> initVideo() async {
    try {
      final raw =
          widget.card['data_json'] ??
          widget.card['data'] ??
          widget.card['content'];

      if (raw == null) {
        setError("Video data not found");
        return;
      }

      final parsed = raw is String ? jsonDecode(raw) : raw;

      final String videoUrl = (parsed['url'] ?? "").toString();

      title = (widget.card['title'] ?? parsed['title'] ?? "Learning Video")
          .toString();

      subtitle = (parsed['description'] ?? "Watch carefully and answer quizzes")
          .toString();

      interactions = parsed['interactions'] ?? [];

      if (videoUrl.isEmpty) {
        setError("Video URL missing");
        return;
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        setError("Windows video not configured.\nUse Android / iOS / Web");
        return;
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await _controller!.initialize();
      await _controller!.setVolume(1.0);

      _controller!.addListener(videoListener);

      await restoreProgress();

      if (mounted) {
        setState(() {
          isReady = true;
        });
      }

      showTempOverlay();
    } catch (e) {
      setError(e.toString());
    }
  }

  // ===================================================
  // ERROR
  // ===================================================
  void setError(String msg) {
    if (!mounted) return;

    setState(() {
      hasError = true;
      errorText = msg;
    });
  }

  // ===================================================
  // LISTENER
  // ===================================================
  void videoListener() async {
    if (_controller == null) return;
    if (!_controller!.value.isInitialized) return;

    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;

    if (mounted) {
      setState(() {
        isPlaying = _controller!.value.isPlaying;
      });
    }

    await saveProgress();

    if (dur.inSeconds > 0 &&
        pos.inSeconds >= dur.inSeconds - 1 &&
        !videoEnded) {
      videoEnded = true;
      autoNextCard();
    }

    for (var interaction in interactions) {
      final int timestamp = interaction['timestamp'] ?? 0;
      final String id = interaction['id'].toString();

      if (pos.inSeconds >= timestamp && !triggered.contains(id)) {
        triggered.add(id);

        if (interaction['data']['pauseVideo'] == true) {
          _controller!.pause();
        }

        showQuiz(interaction);
      }
    }
  }

  // ===================================================
  // AUTO NEXT
  // ===================================================
  void autoNextCard() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Video Completed 🎉")));

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 700),
      );
    });
  }

  // ===================================================
  // SAVE PROGRESS
  // ===================================================
  Future<void> saveProgress() async {
    if (_controller == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      "video_${widget.card['id']}",
      _controller!.value.position.inSeconds,
    );
  }

  // ===================================================
  // RESTORE PROGRESS
  // ===================================================
  Future<void> restoreProgress() async {
    final prefs = await SharedPreferences.getInstance();

    final sec = prefs.getInt("video_${widget.card['id']}");

    if (sec != null && sec > 0) {
      await _controller!.seekTo(Duration(seconds: sec));
    }
  }

  // ===================================================
  // PLAY / PAUSE
  // ===================================================
  void togglePlayPause() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }

    showTempOverlay();
  }

  // ===================================================
  // MUTE
  // ===================================================
  void toggleMute() {
    if (_controller == null) return;

    if (isMuted) {
      _controller!.setVolume(1);
    } else {
      _controller!.setVolume(0);
    }

    setState(() {
      isMuted = !isMuted;
    });
  }

  // ===================================================
  // SPEED
  // ===================================================
  void changeSpeed(double val) async {
    speed = val;
    await _controller!.setPlaybackSpeed(val);
    setState(() {});
  }

  // ===================================================
  // OVERLAY
  // ===================================================
  void showTempOverlay() {
    setState(() {
      showOverlay = true;
    });

    overlayTimer?.cancel();

    overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showOverlay = false;
        });
      }
    });
  }

  // ===================================================
  // QUIZ
  // ===================================================
  void showQuiz(Map interaction) {
    final data = interaction['data'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            data['question'] ?? "",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: (data['options'] as List).map<Widget>((opt) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  onPressed: () {
                    final correct = opt['id'] == data['correctOptionId'];

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          correct
                              ? "Correct ✅ +${data['points']} XP"
                              : "Wrong ❌",
                        ),
                      ),
                    );

                    _controller?.play();
                  },
                  child: Text(opt['text']),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ===================================================
  // FORMAT
  // ===================================================
  String format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');

    return "${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}";
  }

  // ===================================================
  // BUILD
  // ===================================================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final bool mobile = width < 600;
    final double radius = mobile ? 18 : 24;
    final double margin = mobile ? 14 : 22;
    final double titleSize = mobile ? 17 : 22;
    final double subSize = mobile ? 13 : 15;
    final double cardWidth = width > 900 ? 850 : width;

    if (hasError) {
      return Center(
        child: SizedBox(width: cardWidth, child: errorUI(radius, margin)),
      );
    }

    if (!isReady || _controller == null) {
      return Center(
        child: SizedBox(width: cardWidth, child: loaderUI(radius, margin)),
      );
    }

    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    return Center(
      child: SizedBox(
        width: cardWidth,
        child: Container(
          margin: EdgeInsets.all(margin),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // VIDEO
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: GestureDetector(
                        onTap: showTempOverlay,
                        child: VideoPlayer(_controller!),
                      ),
                    ),

                    if (showOverlay) Container(color: Colors.black26),

                    if (showOverlay)
                      GestureDetector(
                        onTap: togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: mobile ? 34 : 42,
                          ),
                        ),
                      ),

                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        children: [
                          speedMenu(),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: toggleMute,
                            icon: Icon(
                              isMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // INFO
              Padding(
                padding: EdgeInsets.all(mobile ? 14 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: subSize,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Slider(
                      activeColor: Colors.red,
                      value: position.inSeconds.toDouble().clamp(
                        0,
                        duration.inSeconds == 0
                            ? 1
                            : duration.inSeconds.toDouble(),
                      ),
                      max: duration.inSeconds == 0
                          ? 1
                          : duration.inSeconds.toDouble(),
                      onChanged: (v) {
                        _controller!.seekTo(Duration(seconds: v.toInt()));
                      },
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(format(position)),
                        Text(format(duration)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================================================
  Widget speedMenu() {
    return PopupMenuButton<double>(
      color: Colors.white,
      onSelected: changeSpeed,
      icon: Text(
        "${speed}x",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 1.0, child: Text("1x")),
        const PopupMenuItem(value: 1.5, child: Text("1.5x")),
        const PopupMenuItem(value: 2.0, child: Text("2x")),
      ],
    );
  }

  // ===================================================
  Widget loaderUI(double radius, double margin) {
    return Container(
      height: 250,
      margin: EdgeInsets.all(margin),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  // ===================================================
  Widget errorUI(double radius, double margin) {
    return Container(
      margin: EdgeInsets.all(margin),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 60),
          const SizedBox(height: 12),
          Text(title),
          const SizedBox(height: 8),
          Text(errorText, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ===================================================
  @override
  void dispose() {
    overlayTimer?.cancel();
    _controller?.removeListener(videoListener);
    _controller?.dispose();
    super.dispose();
  }
}
