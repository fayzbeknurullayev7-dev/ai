import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _bg = Color(0xFF0D0F14);
  static const _surface = Color(0xFF161B25);
  static const _card = Color(0xFF1E2535);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0xFF8B85FF);
  static const _textPrimary = Color(0xFFE8EAF0);
  static const _textSecondary = Color(0xFF8892A4);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        surface: _surface,
        primary: _accent,
        secondary: _accentGlow,
        onPrimary: Colors.white,
        onSurface: _textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.copyWith(
              bodyLarge: const TextStyle(color: _textPrimary),
              bodyMedium: const TextStyle(color: _textPrimary),
              bodySmall: const TextStyle(color: _textSecondary),
            ),
      ),
      cardColor: _card,
      appBarTheme: AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        titleTextStyle: GoogleFonts.inter(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    );
  }
}
