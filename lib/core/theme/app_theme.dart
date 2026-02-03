import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF070B14), // Deeper dark from onboarding
    cardColor: const Color(0xFF161616),
    primaryColor: const Color(0xFF8B5CF6), // Unified Purple Accent
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF8B5CF6),
      surface: const Color(0xFF161616),
      onPrimary: Colors.white,
      secondary: const Color(0xFF8B5CF6).withAlpha(25),
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.bricolageGrotesque(
        fontSize: 22, 
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyMedium: GoogleFonts.bricolageGrotesque(
        fontSize: 15,
        color: Colors.white70,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
  );
}
