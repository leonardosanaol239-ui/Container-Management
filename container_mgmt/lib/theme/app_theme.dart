import 'package:flutter/material.dart';

/// Gothong Southern brand color palette
class AppColors {
  // Primary - Canary/Cyber Yellow (dominant brand color)
  static const Color yellow = Color(0xFFFFD300);
  static const Color yellowLight = Color(0xFFFFF176);
  static const Color yellowDark = Color(0xFFE6BE00);

  // Accent - Scarlet Red
  static const Color red = Color(0xFFFF2800);
  static const Color redDark = Color(0xFFCC1F00);
  static const Color redSoft = Color(0xFFe0474c); // Smiley Red

  // Accent - Lincoln Green
  static const Color green = Color(0xFF0B560D);
  static const Color greenLight = Color(0xFF1A7A1C);
  static const Color greenSoft = Color(0xFF98f29b); // Live Green

  // Neutral
  static const Color darkBg = Color(0xFF1A1A0A);   // Deep warm dark
  static const Color cardBg = Color(0xFF2A2A15);   // Slightly lighter card bg
  static const Color surface = Color(0xFFFFFDE7);  // Warm white surface
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A0A);
  static const Color textGrey = Color(0xFF757575);
  static const Color divider = Color(0xFFE0D800);

  // Status colors
  static const Color laden = Color(0xFFFFD300);   // Yellow for laden
  static const Color empty = Color(0xFFFF2800);   // Red for empty
  static const Color activeGreen = Color(0xFF0B560D);
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
        scaffoldBackgroundColor: const Color(0xFFFFFDE7),
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
            shadowColor: AppColors.yellowDark.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
            borderSide: BorderSide(color: AppColors.yellow.withOpacity(0.4)),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: AppColors.textGrey),
        ),
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 3,
          shadowColor: AppColors.yellow.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 8,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1.5,
        ),
      );
}
