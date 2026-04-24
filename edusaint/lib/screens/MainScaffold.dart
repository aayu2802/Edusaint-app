import 'package:flutter/material.dart';
import 'package:edusaint/screens/widgets/bottom_nav_bar.dart';
import 'package:edusaint/screens/widgets/top_nav_bar.dart';

class MainScaffold extends StatefulWidget {
  final Widget? body;
  final Widget Function()? bodyBuilder;

  final int selectedIndex;

  const MainScaffold({
    super.key,
    this.body,
    this.bodyBuilder,
    required this.selectedIndex,
  }) : assert(
         body != null || bodyBuilder != null,
         'Either body or bodyBuilder must be provided',
       );

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    // ✅ bodyBuilder priority
    if (widget.bodyBuilder != null) {
      try {
        content = widget.bodyBuilder!();
      } catch (e) {
        debugPrint("ERROR in bodyBuilder: $e");
        content = const Center(child: Text("Error loading content"));
      }
    } else {
      content = widget.body!;
    }

    return Scaffold(
      appBar: const TopNavBar(color: Color(0xFFB7C6FF)),

      body: content,

      bottomNavigationBar: BottomNavBar(
        selectedIndex: _currentIndex,
        color: const Color(0xFFB7C6FF),
      ),
    );
  }
}
