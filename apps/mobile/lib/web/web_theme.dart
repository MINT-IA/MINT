import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Builds the premium theme for the MINT web app.
///
/// Mirrors `_buildPremiumTheme()` from app.dart so the web app
/// has an identical look & feel without importing the mobile app widget.
ThemeData buildWebTheme() {
  final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: MintColors.background,
    colorScheme: const ColorScheme.light(
      primary: MintColors.primary,
      onPrimary: Colors.white,
      secondary: MintColors.accent,
      onSecondary: Colors.white,
      surface: MintColors.appleSurface,
      onSurface: MintColors.textPrimary,
      error: MintColors.error,
      outline: MintColors.border,
    ),
    textTheme: textTheme.copyWith(
      displayLarge: GoogleFonts.outfit(
        textStyle: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: MintColors.textPrimary,
        ),
      ),
      headlineLarge: GoogleFonts.outfit(
        textStyle: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: MintColors.textPrimary,
        ),
      ),
      headlineMedium: GoogleFonts.outfit(
        textStyle: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: MintColors.textPrimary,
        ),
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: MintColors.textPrimary,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        color: MintColors.textPrimary,
        height: 1.5,
        fontSize: 16,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: MintColors.textSecondary,
        height: 1.4,
        fontSize: 14,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontFamily: 'Outfit',
        color: MintColors.textPrimary,
        fontSize: 20,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: MintColors.textPrimary, size: 22),
    ),
    cardTheme: CardThemeData(
      color: MintColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MintColors.lightBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MintColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MintColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        side: const BorderSide(color: MintColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MintColors.appleSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MintColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    ),
    dividerTheme: const DividerThemeData(
      color: MintColors.lightBorder,
      thickness: 1,
    ),
  );
}
