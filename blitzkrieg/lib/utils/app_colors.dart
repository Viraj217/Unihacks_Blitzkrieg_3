import 'package:flutter/material.dart';

class AppTheme {
  // Gradient Colors
  static const Color gradientStart = Color(0xFF2B0A3D);
  static const Color gradientEnd = Color(0xFF5F259F);

  // Primary Colors (from your main.dart)
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color lightPurpleBorder = Color(0xFFD6BCFA);

  // Gradient Decoration method for easy reuse
  static BoxDecoration get backgroundGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [gradientStart, gradientEnd],
    ),
  );
}
