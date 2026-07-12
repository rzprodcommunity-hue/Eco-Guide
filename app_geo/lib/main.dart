import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

/// Brand green from the EcoGuide / Eco-tracer logo (white lotus on green).
const Color kBrandGreen = Color(0xFF22B53A);
const Color kBrandGreenDark = Color(0xFF0E7A23);

void main() {
  runApp(const AppGeo());
}

class AppGeo extends StatelessWidget {
  const AppGeo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eco-tracer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandGreen,
          primary: kBrandGreen,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBrandGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kBrandGreen,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
