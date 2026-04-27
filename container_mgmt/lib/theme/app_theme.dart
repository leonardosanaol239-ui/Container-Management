import 'package:flutter/material.dart';

/// Gothong Southern brand color palette - Pantone Official Colors
class AppColors {
  // PRIMARY COLOR - Cyber Yellow (Pantone)
  // HEX #ffd300 | R-255 G-211 B-0
  static const Color yellow = Color(0xFFFFD300);
  static const Color yellowLight = Color(0xFFFFF9CC); // Lighter tint
  static const Color yellowDark = Color(0xFFCCA900); // Darker shade

  // SECONDARY COLOR - Scarlet Red (Pantone)
  // HEX #FF2800 | R-255 G-40 B-0
  static const Color red = Color(0xFFFF2800);
  static const Color redLight = Color(0xFFFF6B4D); // Lighter tint
  static const Color redDark = Color(0xFFCC2000); // Darker shade
  static const Color redSoft = Color(0xFFE0474C); // Smiley Red variant

  // SECONDARY COLOR - Lincoln Green (Pantone)
  // HEX #0B560D | R-11 G-86 B-13
  static const Color green = Color(0xFF0B560D);
  static const Color greenLight = Color(0xFF1A7A1C); // Lighter tint
  static const Color greenSoft = Color(0xFF98F29B); // Live Green variant

  // Neutral colors
  static const Color surface = Color(0xFFFFFDE7); // Warm white surface
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A0A); // Almost black
  static const Color textGrey = Color(0xFF757575);
  static const Color divider = Color(0xFFE0D800);

  // Status colors (using primary palette)
  static const Color laden = yellow; // Yellow for laden
  static const Color empty = Color(0xFF2196F3); // Blue for empty
  static const Color active = green; // Green for active
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      brightness: Brightness.light,
      primary: AppColors.yellow,
      onPrimary: AppColors.textDark,
      secondary: AppColors.green,
      onSecondary: AppColors.white,
      error: AppColors.red,
      surface: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.yellow,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.textDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textDark,
        elevation: 2,
        shadowColor: AppColors.yellowDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.yellow, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.yellow.withValues(alpha: 0.4)),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.textGrey),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 3,
      shadowColor: AppColors.yellow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 8,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1.5,
    ),
  );
}
