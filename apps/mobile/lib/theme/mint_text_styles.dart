import 'package:flutter/material.dart';
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
///
/// ===== MVP-GOOGLEFONTS-PURGE-V1 (2026-05-10) =====
/// All helpers below now reference the bundled Fontshare families declared in
/// `apps/mobile/pubspec.yaml` (Supreme + Gambarino). Phase 92 partially swapped
/// the landing hero (Gambarino) and added 5 bundled helpers ; this purge
/// finishes the job by mapping the remaining 21 legacy helpers to bundled
/// equivalents:
///   Montserrat → Supreme (geometric sans, similar grotesque rhythm)
///   Inter      → Supreme (neutral sans, close metric)
///   Fraunces   → Gambarino (serif italic — synthetic italic via skew)
/// Source: ROADMAP.md L135 (« MVP-GOOGLEFONTS-PURGE-V1 ») +
///         test/golden/landing_gambarino_test.dart:14-31 (purge rationale).
///
/// Wave 1 findings carried over from Phase 92:
///   - Supreme has no weight 600. Flutter's nearest-weight matcher resolves
///     `FontWeight.w600` requests to the bundled Supreme-Bold (700). The
///     TextStyle field keeps `w600` (design intent) so unit tests assert on
///     spec, not on rendered weight.
///   - Supreme has no weight 800. Same nearest-match rule → renders Bold (700).
///   - Gambarino has no real italic glyph variant ; italic is synthesized at
///     render time via Flutter's skew transform on Gambarino-Regular.otf.
///   - No bundled italic Supreme. The `micro` helper retains
///     `fontStyle: FontStyle.italic` ; synthesized via skew.
///
/// G2 device-gate: visual fidelity of Inter→Supreme + Montserrat→Supreme
/// swaps across non-landing surfaces (aujourdhui, anonymous chat, onboarding,
/// privacy) MUST be reviewed by Julien on a real device before this PR
/// merges to staging.
class MintTextStyles {
  MintTextStyles._();

  // ── Display (dominant numbers) ──

  /// The signature hero number for MintCountUp / Pulse (56pt).
  /// Used exclusively in Revelation 5 temps — the single dominant number
  /// that anchors an entire screen. Tighter height for visual impact.
  static TextStyle displayHero({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.0,
        color: color ?? MintColors.textPrimary,
      );

  /// The ONE dominant number on Hero screens (48pt).
  /// Example: "4'416 CHF/mois", "63%", "52.8%"
  static TextStyle displayLarge({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.1,
        color: color ?? MintColors.textPrimary,
      );

  /// Result number on Simulator screens (32pt).
  /// Example: chiffre-choc, result of a calculation.
  static TextStyle displayMedium({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: color ?? MintColors.textPrimary,
      );

  /// Secondary result number (28pt). Sub-totals, comparison values.
  static TextStyle displaySmall({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.15,
        color: color ?? MintColors.textPrimary,
      );

  // ── Headlines (titles) ──

  /// Screen title (26pt). One per screen.
  static TextStyle headlineLarge({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: color ?? MintColors.textPrimary,
      );

  /// Section title (22pt). Max 2-3 per screen.
  static TextStyle headlineMedium({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color ?? MintColors.textPrimary,
      );

  /// Smaller section title (20pt). Navigation labels, feature headers.
  static TextStyle headlineSmall({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color ?? MintColors.textPrimary,
      );

  // ── Title (card labels, subtitles) ──

  /// Large card title (18pt semibold). Prominent card headers, tab labels.
  static TextStyle titleLarge({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color ?? MintColors.textPrimary,
      );

  /// Card label, subtitle (16pt semibold).
  static TextStyle titleMedium({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color ?? MintColors.textPrimary,
      );

  // ── Body (content text) ──

  /// Primary body text (16pt).
  static TextStyle bodyLarge({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color ?? MintColors.textSecondary,
      );

  /// Secondary body text (14pt). Most common text style.
  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color ?? MintColors.textSecondary,
      );

  /// Labels, hint text, form field labels (13pt).
  static TextStyle bodySmall({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color ?? MintColors.textMuted,
      );

  // ── Labels (captions, metadata) ──

  /// Data labels, table cells, secondary info (15pt).
  static TextStyle labelLarge({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color ?? MintColors.textSecondary,
      );

  /// Medium labels, chip text, row values (12pt). Most frequent override.
  static TextStyle labelMedium({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color ?? MintColors.textMuted,
      );

  /// Captions, metadata, small labels (11pt).
  static TextStyle labelSmall({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color ?? MintColors.textMuted,
      );

  /// Tiny text, footnotes, badges (9pt).
  static TextStyle labelTiny({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 9,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: color ?? MintColors.textMuted,
      );

  // ── Brand ──

  /// MINT wordmark logo text (18pt Supreme, w800, wide tracking).
  /// Used exclusively on landing screen header.
  static TextStyle brandLogo({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        color: color ?? MintColors.textPrimary,
      );

  // ── Micro ──

  /// Disclaimer, legal mentions (10pt italic).
  /// Italic synthesized via skew (Supreme has no italic glyph).
  static TextStyle micro({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontSize: 10,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.3,
        color: color ?? MintColors.textMuted,
      );

  // ── Editorial (Handoff 2 — Gambarino italic, 2 écrans max) ──
  // Source: ~/Downloads/handoff 2/colors_and_type.css §Typography (originally
  // Fraunces ; remapped to Gambarino italic per MVP-GOOGLEFONTS-PURGE-V1).
  // Use ONLY on hero / disclosure / first-screen surfaces. Italic is the
  // single emphasis lever — apply via TextSpan italic on the 1-3 mots clés
  // that carry the meaning.

  /// Editorial display headline (32pt Gambarino italic). Hero numbers in
  /// situational scenes. Hand off 2 §grammaire « Une idée / écran ».
  static TextStyle editorialDisplay({Color? color}) => TextStyle(
        fontFamily: 'Gambarino',
        fontStyle: FontStyle.italic,
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 1.25,
        letterSpacing: -0.5,
        color: color ?? MintColors.inkPrimary,
      );

  /// Editorial large headline (22pt Gambarino italic). Disclosure headline,
  /// first-onboarding question, beta sheet headline.
  static TextStyle editorialLarge({Color? color}) => TextStyle(
        fontFamily: 'Gambarino',
        fontStyle: FontStyle.italic,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: -0.3,
        color: color ?? MintColors.inkPrimary,
      );

  /// Editorial body (16pt Gambarino italic). Coach message in conversion
  /// sheets, 1-2 lines max. Italic em on key words via TextSpan.
  static TextStyle editorialBody({Color? color}) => TextStyle(
        fontFamily: 'Gambarino',
        fontStyle: FontStyle.italic,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color ?? MintColors.inkPrimary,
      );

  // ============ MINT v2 PHASE 92 — Bundled Supreme + Gambarino ============
  // Added 2026-05-09 (Phase 92 MVP-FONTS-TOKENS-V2 / FONT-03).
  // Source: .planning/decisions/2026-05-08-perimeter-mvp-fonts-tokens-v2/STUB.md F3.*
  // Fonts bundled via apps/mobile/pubspec.yaml flutter.fonts (Plan 92-01).
  // These styles do NOT use GoogleFonts — they reference the bundled families
  // by name. Family strings 'Supreme' and 'Gambarino' MUST match pubspec.yaml.
  //
  // Wave 1 finding propagation (see .planning/phases/92-mvp-fonts-tokens-v2/92-01-SUMMARY.md):
  //   - Supreme catalog has no weight 600. Flutter's nearest-weight matcher
  //     resolves FontWeight.w600 requests to the bundled Supreme-Bold (700).
  //     The TextStyle field stays w600 (per spec) so unit tests assert on intent.
  //   - Gambarino catalog has no real italic. Italic is synthesized via Flutter's
  //     skew transform on Gambarino-Regular.otf at render time. Visual fidelity
  //     of synthetic italic at display sizes (40-56pt) is a G2 device-gate concern.

  /// Landing hero (56pt Gambarino italic w400).
  /// Used on the landing screen primary phrase per STUB §F5.
  ///
  /// NOTE: Italic is synthesized at render time (Fontshare ships no italic
  /// glyph variant — see Wave 1 finding #2). Visual fidelity vs. real italic
  /// glyphs validated at G2 sim screenshot review.
  static TextStyle displayGambarinoItalic56({Color? color}) => TextStyle(
        fontFamily: 'Gambarino',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontSize: 56,
        height: 1.15,
        letterSpacing: -0.5,
        color: color ?? MintColors.inkPrimary,
      );

  /// Onboarding hero (40pt Gambarino italic w400).
  /// Smaller Gambarino variant for non-landing hero contexts.
  ///
  /// NOTE: Italic is synthesized at render time (see [displayGambarinoItalic56]
  /// for synthetic-italic rationale). Visual fidelity TBD at G2.
  static TextStyle displayGambarinoItalic40({Color? color}) => TextStyle(
        fontFamily: 'Gambarino',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontSize: 40,
        height: 1.2,
        letterSpacing: -0.4,
        color: color ?? MintColors.inkPrimary,
      );

  /// Card headline (18pt Gambarino medium, non-italic).
  /// Used when an editorial card needs a serif headline without the italic
  /// emphasis reserved for first-screen hero copy.
  static TextStyle titleGambarino18Medium({Color? color}) => TextStyle(
        fontFamily: 'Gambarino',
        fontWeight: FontWeight.w500,
        fontSize: 18,
        height: 1.3,
        color: color ?? MintColors.inkPrimary,
      );

  /// Card / section title (18pt Supreme semibold).
  ///
  /// NOTE: Fontshare's Supreme catalog ships no weight 600 (Wave 1 finding #1).
  /// The TextStyle requests `FontWeight.w600` (design-system intent) but
  /// Flutter's nearest-weight matcher resolves to the bundled Supreme-Bold (700)
  /// at render time. Keep `w600` here so callsites and tests reflect intent;
  /// rendered emphasis is one notch heavier than spec until a real Semibold
  /// is sourced.
  static TextStyle titleSupreme18Semibold({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontWeight: FontWeight.w600,
        fontSize: 18,
        height: 1.3,
        color: color ?? MintColors.inkPrimary,
      );

  /// Body text (15pt Supreme regular). MINT v2 default reading size.
  static TextStyle bodySupreme15Regular({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 1.5,
        color: color ?? MintColors.inkPrimary,
      );

  /// Eyebrow / micro-label (12pt Supreme, uppercase callsite, letterSpacing 0.25).
  /// Note: callsites must apply `.toUpperCase()` to the displayed text — this
  /// style only encodes the letterSpacing + size. Avoids duplicating uppercase
  /// transform across screens.
  static TextStyle labelSupreme12Uppercase025LS({Color? color}) => TextStyle(
        fontFamily: 'Supreme',
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.25,
        height: 1.3,
        color: color ?? MintColors.textMutedAaa,
      );
}
