import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF0E0E11);
  static const Color surface = Color(0xFF16161B);
  static const Color card = Color(0xFF1F1F26);
  static const Color primaryRose = Color(0xFFF43F5E);
  static const Color primaryRoseLight = Color(0xFFFB7185);
  // Alias kompatibilitas penuh untuk seluruh komponen yang memanggil primaryGreen
  static const Color primaryGreen = primaryRose;
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color divider = Color(0xFF262630);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      scaffoldBackgroundColor: background,
      primaryColor: primaryRose,
      colorScheme: const ColorScheme.dark(
        primary: primaryRose,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: textPrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
