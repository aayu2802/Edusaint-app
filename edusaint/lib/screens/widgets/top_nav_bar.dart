import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:edusaint/screens/settings.dart';
import 'package:edusaint/screens/notification.dart';
import 'package:edusaint/screens/leaderboard.dart';

class TopNavBar extends StatefulWidget implements PreferredSizeWidget {
  final Color color;

  const TopNavBar({super.key, required this.color});

  @override
  State<TopNavBar> createState() => _TopNavBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);
}

class _TopNavBarState extends State<TopNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onIconTap(VoidCallback onPressed) {
    _controller.forward(from: 0);
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0A0A0F).withOpacity(0.95),
                const Color(0xFF101A36).withOpacity(0.85),
                widget.color.withOpacity(0.65),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildLogo(), _buildRightSection(context)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- LOGO ----------------
  Widget _buildLogo() {
    return Row(
      children: const [
        Icon(Icons.school, color: Colors.white),
        SizedBox(width: 8),
        Text(
          "EduSaint",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ---------------- RIGHT ICONS ----------------
  Widget _buildRightSection(BuildContext context) {
    return Row(
      children: [
        _icon(Icons.notifications, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          );
        }),
        _icon(Icons.emoji_events, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          );
        }),
        _icon(Icons.settings, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        }),
      ],
    );
  }

  // ---------------- ICON ----------------
  Widget _icon(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => _onIconTap(onTap),
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 0.85).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          ),
          child: Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
