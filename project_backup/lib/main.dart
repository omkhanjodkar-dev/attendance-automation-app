import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'startup_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NoProxy Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(), // Modern font
      ),
      home: const StartupScreen(),
    );
  }
}