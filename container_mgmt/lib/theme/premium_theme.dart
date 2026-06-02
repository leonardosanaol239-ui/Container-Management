import 'package:flutter/material.dart';

/// Premium Logistics Theme for Container Management System
/// Modern, enterprise-grade color palette inspired by international shipping companies
class PremiumColors {
  // Primary Colors
  static const deepEmerald = Color(0xFF0B5D1E);
  static const emeraldLight = Color(0xFF0F7A28);
  static const emeraldDark = Color(0xFF084515);

  // Secondary Colors
  static const logisticsGold = Color(0xFFF5C400);
  static const goldLight = Color(0xFFF8D84A);
  static const goldDark = Color(0xFFD4A900);

  // Accent Colors
  static const orangeRed = Color(0xFFFF5A1F);
  static const orangeLight = Color(0xFFFF7A47);
  static const orangeDark = Color(0xFFE54A0F);

  // Background & Surface
  static const background = Color(0xFFF5F6F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceGlass = Color(0xFFFAFAF8);

  // Text Colors
  static const textDark = Color(0xFF1E1E1E);
  static const textMedium = Color(0xFF4A4A4A);
  static const textLight = Color(0xFF7A7A7A);
  static const textHint = Color(0xFFAAAAAA);

  // Status Colors
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Container Status Colors
  static const laden = Color(0xFFF5C400);
  static const mtFood = Color(0xFF2E7D32);
  static const fsl = Color(0xFF1565C0);
  static const stripping = Color(0xFFE65100);
  static const mtNonFood = Color(0xFF6A1B9A);
  static const empty = Color(0xFFBDBDBD);

  // Gradient Definitions
  static const emeraldGradient = LinearGradient(
    colors: [deepEmerald, emeraldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [goldDark, logisticsGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const orangeGradient = LinearGradient(
    colors: [orangeDark, orangeRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glass Effect Colors
  static Color glassWhite = Colors.white.withValues(alpha: 0.7);
  static Color glassBorder = Colors.white.withValues(alpha: 0.2);
}

/// Premium Theme Data
class PremiumTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: PremiumColors.deepEmerald,
        secondary: PremiumColors.logisticsGold,
        tertiary: PremiumColors.orangeRed,
        surface: PremiumColors.surface,
        error: PremiumColors.error,
        onPrimary: Colors.white,
        onSecondary: PremiumColors.textDark,
        onSurface: PremiumColors.textDark,
      ),
      fontFamily: 'Inter',
      scaffoldBackgroundColor: PremiumColors.background,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: PremiumColors.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PremiumColors.surfaceGlass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: PremiumColors.deepEmerald,
            width: 2,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: PremiumColors.emeraldLight,
        secondary: PremiumColors.logisticsGold,
        tertiary: PremiumColors.orangeRed,
        surface: const Color(0xFF1E1E1E),
        error: PremiumColors.error,
        onPrimary: Colors.white,
        onSecondary: PremiumColors.textDark,
        onSurface: Colors.white,
      ),
      fontFamily: 'Inter',
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}

/// Premium Card Styles
class PremiumCard {
  static BoxDecoration glass({
    Color? color,
    double borderRadius = 20,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: color ?? PremiumColors.glassWhite,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(color: PremiumColors.glassBorder, width: 1.5)
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration gradient({
    required Gradient gradient,
    double borderRadius = 20,
  }) {
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

/// Premium Text Styles
class PremiumText {
  static const displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: PremiumColors.textDark,
    letterSpacing: -1.5,
  );

  static const displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: PremiumColors.textDark,
    letterSpacing: -1.0,
  );

  static const headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: PremiumColors.textDark,
    letterSpacing: -0.5,
  );

  static const headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: PremiumColors.textDark,
  );

  static const titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: PremiumColors.textDark,
  );

  static const titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: PremiumColors.textDark,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: PremiumColors.textMedium,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: PremiumColors.textMedium,
  );

  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: PremiumColors.textDark,
    letterSpacing: 0.5,
  );

  static const labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: PremiumColors.textLight,
    letterSpacing: 0.5,
  );
}
