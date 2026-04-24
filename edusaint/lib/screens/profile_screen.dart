import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'MainScaffold.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;

  String name = "";
  String userClass = "";
  String email = "";
  String phone = "";
  String profileImage = "";

  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  String? token;

  @override
  void initState() {
    super.initState();
    initProfile();
  }

  // ✅ FIXED FUNCTION (NO RECURSION)
  Future<void> initProfile() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString("token");

    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    // ✅ LOAD FROM LOCAL STORAGE
    setState(() {
      name = prefs.getString("name") ?? "Student";
      email = prefs.getString("email") ?? "";
      userClass = prefs.getInt("selected_class_id")?.toString() ?? "";
      phone = "";
      profileImage = "";
      isLoading = false;
    });

    print("PROFILE LOADED: $name");
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      selectedIndex: 3,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: initProfile,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFE6ECFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _profileCard(),
                      const SizedBox(height: 20),
                      _progressCard(),
                      const SizedBox(height: 20),
                      _calendarCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ================= PROFILE =================
  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6CFF), Color(0xFF7F8CFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white,
            backgroundImage: profileImage.isNotEmpty
                ? NetworkImage(profileImage)
                : null,
            child: profileImage.isEmpty
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : "Student",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Class $userClass",
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(email, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= PROGRESS =================
  Widget _progressCard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _StatCard("🔥", "Streak", "7"),
        _StatCard("⭐", "XP", "120"),
        _StatCard("🎁", "Rewards", "10"),
      ],
    );
  }

  // ================= CALENDAR =================
  Widget _calendarCard() {
    return _glassCard(
      child: TableCalendar(
        firstDay: DateTime.utc(2020),
        lastDay: DateTime.utc(2030),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            selectedDay = selected;
            focusedDay = focused;
          });
        },
      ),
    );
  }

  // ================= GLASS =================
  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ================= STAT CARD =================
class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatCard(this.emoji, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}
