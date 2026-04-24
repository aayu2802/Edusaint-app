import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('topic_cache');

  // 🔥 DEBUG: Check SharedPreferences on app start
  final prefs = await SharedPreferences.getInstance();
  print('=== APP STARTUP DEBUG ===');
  print('All keys in SharedPreferences: ${prefs.getKeys()}');
  print('Token value: ${prefs.getString("token")}');
  print('========================');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const EdusaintApp(),
    ),
  );
}

class EdusaintApp extends StatelessWidget {
  const EdusaintApp({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return MaterialApp(
      title: 'Edusaint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xFFF4F6FF),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
