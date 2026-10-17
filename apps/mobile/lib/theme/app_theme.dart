import 'package:flutter/material.dart';

class AppTheme {
  // ─── Earthy Indian Handicraft Palette ───────────────────────────────────────
  static const Color terracotta = Color(0xFFC85A32);
  static const Color terracottaDark = Color(0xFF9E3A19);
  static const Color terracottaLight = Color(0xFFFBECE6);

  static const Color indigo = Color(0xFF2C3E6B);
  static const Color indigoDark = Color(0xFF1B2745);
  static const Color indigoLight = Color(0xFFE9EDF5);

  static const Color turmeric = Color(0xFFE09F3E);
  static const Color turmericDark = Color(0xFFC78322);
  static const Color turmericLight = Color(0xFFFCF5E8);

  static const Color backgroundSand = Color(0xFFFAF7F2);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color borderWarm = Color(0xFFE5DDD0);

  static const Color textCharcoal = Color(0xFF262220);
  static const Color textMuted = Color(0xFF6B645F);

  static const Color successGreen = Color(0xFF2E7D32);
  static const Color successGreenLight = Color(0xFFE8F5E9);

  // Minimum touch target specification for low-literacy accessibility
  static const double minTouchTarget = 56.0;

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundSand,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: terracotta,
        onPrimary: surfaceWhite,
        secondary: indigo,
        onSecondary: surfaceWhite,
        tertiary: turmeric,
        onTertiary: textCharcoal,
        error: Color(0xFFD32F2F),
        onError: surfaceWhite,
        surface: surfaceWhite,
        onSurface: textCharcoal,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundSand,
        foregroundColor: textCharcoal,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textCharcoal,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: surfaceWhite,
          minimumSize: const Size(double.infinity, minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: terracotta,
          minimumSize: const Size(double.infinity, minTouchTarget),
          side: const BorderSide(color: terracotta, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderWarm, width: 1),
        ),
      ),
    );
  }
}
