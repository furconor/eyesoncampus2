import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors from CSS
  static const Color bg = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surface2 = Color(0xFF141414);
  static const Color surface3 = Color(0xFF1E1E1E);
  static const Color border = Color(0x26FFFFFF); // 15% white
  static const Color accent = Color(0xFFD2AC47); // Refined Premium Gold
  static const Color accent2 = Color(0xFF8B6B23); // Deep Antique Gold
  static const Color red = Color(0xFFFF3B30);
  static const Color blue = Color(0xFF0A84FF);
  static const Color text = Color(0xFFF5F5F5);
  static const Color muted = Color(0xFF8E8E93);
  static const Color muted2 = Color(0xFF636366);
  static const Color glow = Color(0x26D2AC47); // Subtler 15% gold glow

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      canvasColor: surface2,
      fontFamily: GoogleFonts.dmSans().fontFamily,
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.dmSans(color: text),
        bodyMedium: GoogleFonts.dmSans(color: text),
        displayLarge: GoogleFonts.cormorantGaramond(
          color: accent,
          fontWeight: FontWeight.w300,
        ),
        displayMedium: GoogleFonts.cormorantGaramond(
          color: text,
          fontWeight: FontWeight.w300,
        ),
        labelSmall: GoogleFonts.spaceMono(
          color: muted,
          fontWeight: FontWeight.w400,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: muted2),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface2,
        selectedItemColor: accent,
        unselectedItemColor: muted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF0A0800),
          textStyle: GoogleFonts.spaceMono(
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: muted2,
          side: const BorderSide(color: border),
          textStyle: GoogleFonts.spaceMono(
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent2,
        surface: surface,
        error: red,
        onPrimary: Color(0xFF0A0800),
        onSecondary: Color(0xFF0A0800),
        onSurface: text,
        onError: Colors.white,
      ),
    );
  }
}
