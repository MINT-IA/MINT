import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// MINT Design System — Typography tokens.
///
/// Source of truth: `docs/DESIGN_SYSTEM.md` §3.1
///
/// Usage:
/// ```dart
/// Text('4\'416 CHF', style: MintTextStyles.displayLarge())
/// Text('Ton aperçu', style: MintTextStyles.headlineLarge())
/// Text('Description', style: MintTextStyles.bodyMedium())
/// ```
///
/// Color defaults to the appropriate text hierarchy level.
/// Override with the `color` parameter when needed.
class MintTextStyles {
  MintTextStyles._();

  // ── Display (dominant numbers) ──

  /// The ONE dominant number on Hero screens (48pt).
  /// Example: "4'416 CHF/mois", "63%", "52.8%"
  static TextStyle displayLarge({Color? color}) => GoogleFonts.montserrat(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.1,
        color: color ?? MintColors.textPrimary,
      );

  /// Result number on Simulator screens (32pt).
  /// Example: chiffre-choc, result of a calculation.
  static TextStyle displayMedium({Color? color}) => GoogleFonts.montserrat(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: color ?? MintColors.textPrimary,
      );

  // ── Headlines (titles) ──

  /// Screen title (26pt). One per screen.
  static TextStyle headlineLarge({Color? color}) => GoogleFonts.montserrat(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: color ?? MintColors.textPrimary,
      );

  /// Section title (22pt). Max 2-3 per screen.
  static TextStyle headlineMedium({Color? color}) => GoogleFonts.montserrat(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color ?? MintColors.textPrimary,
      );

  // ── Title (card labels, subtitles) ──

  /// Card label, subtitle (16pt semibold).
  static TextStyle titleMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color ?? MintColors.textPrimary,
      );

  // ── Body (content text) ──

  /// Primary body text (16pt).
  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color ?? MintColors.textSecondary,
      );

  /// Secondary body text (14pt). Most common text style.
  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color ?? MintColors.textSecondary,
      );

  /// Labels, hint text, form field labels (13pt).
  static TextStyle bodySmall({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color ?? MintColors.textMuted,
      );

  // ── Labels (captions, metadata) ──

  /// Captions, metadata, small labels (11pt).
  static TextStyle labelSmall({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color ?? MintColors.textMuted,
      );

  /// Disclaimer, legal mentions (10pt italic).
  static TextStyle micro({Color? color}) => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.3,
        color: color ?? MintColors.textMuted,
      );
}
