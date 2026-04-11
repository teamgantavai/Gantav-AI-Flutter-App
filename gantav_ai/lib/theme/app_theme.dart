import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gantav AI Design System — Refined Color Tokens
class AppColors {
  // Dark theme — deep navy, not pure black (easier on eyes, better contrast)
  static const Color darkBg = Color(0xFF0C0F1A);
  static const Color darkSurface = Color(0xFF141826);
  static const Color darkSurface2 = Color(0xFF1C2235);
  static const Color darkBorder = Color(0xFF252D44);

  // Light theme — warm white with subtle warmth
  static const Color lightBg = Color(0xFFF8F9FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFEFF1F7);
  static const Color lightBorder = Color(0xFFE2E6F0);

  // Primary palette — amber gold is primary (matches logo dot)
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldLight = Color(0xFFFDE68A);
  static const Color goldDark = Color(0xFFB45309);

  // Violet — secondary accent
  static const Color violet = Color(0xFF6D5BDB);
  static const Color violetLight = Color(0xFF9C8FEE);
  static const Color violetDark = Color(0xFF4C3BB0);

  // Teal — progress / success
  static const Color teal = Color(0xFF0DBAB5);
  static const Color tealLight = Color(0xFF5EEAD4);

  // Text — high contrast
  static const Color textLight = Color(0xFFF0F2FA);      // on dark bg
  static const Color textLightSub = Color(0xFFB0B8D4);   // secondary on dark
  static const Color textDark = Color(0xFF0D1026);       // on light bg
  static const Color textDarkSub = Color(0xFF6B7498);    // secondary on light
  static const Color textMuted = Color(0xFF8891B0);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color liveRed = Color(0xFFFF3B30);

  /// Returns the progress color based on percentage (0.0 to 1.0)
  static Color progressColor(double progress) {
    if (progress <= 0.33) return teal;
    if (progress <= 0.66) return gold;
    return violet;
  }
}

class AppTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.violet,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.violet,
        secondary: AppColors.teal,
        tertiary: AppColors.gold,
        surface: AppColors.darkSurface,
        onSurface: AppColors.textLight,
        onSurfaceVariant: AppColors.textLightSub,
        outline: AppColors.darkBorder,
        error: AppColors.error,
      ),
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkBorder,
      textTheme: _buildTextTheme(AppColors.textLight, AppColors.textLightSub),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textLight,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.violet, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textLightSub),
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.violet,
      colorScheme: const ColorScheme.light(
        primary: AppColors.violet,
        secondary: AppColors.teal,
        tertiary: AppColors.gold,
        surface: AppColors.lightSurface,
        onSurface: AppColors.textDark,
        onSurfaceVariant: AppColors.textDarkSub,
        outline: AppColors.lightBorder,
        error: AppColors.error,
      ),
      cardColor: AppColors.lightSurface,
      dividerColor: AppColors.lightBorder,
      textTheme: _buildTextTheme(AppColors.textDark, AppColors.textDarkSub),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.violet, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textDarkSub),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.dmSans(fontSize: 40, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1.5),
      displayMedium: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1),
      headlineLarge: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
      headlineSmall: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleLarge: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      titleSmall: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400, color: primary, height: 1.6),
      bodyMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400, color: secondary, height: 1.6),
      bodySmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, color: secondary, height: 1.5),
      labelLarge: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
      labelMedium: GoogleFonts.dmMono(fontSize: 11, fontWeight: FontWeight.w500, color: secondary),
      labelSmall: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textMuted),
    );
  }
}
