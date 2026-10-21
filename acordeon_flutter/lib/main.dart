import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AcordeonApp(),
    ),
  );
}

class AcordeonApp extends StatelessWidget {
  const AcordeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acordeón Diatónico Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          primary: const Color(0xFF0284C7),
          surface: const Color(0xFFF1F5F9),
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      home: const HomeScreen(),
    );
  }
}
