/// MINT Design System — Spacing tokens.
///
/// Source of truth: `docs/DESIGN_SYSTEM.md` §3.3
///
/// Usage:
/// ```dart
/// SizedBox(height: MintSpacing.xl)  // between sections
/// Padding(padding: MintSpacing.screenH)  // horizontal screen padding
/// ```
class MintSpacing {
  MintSpacing._();

  /// 4px — between label and input, tight grouping.
  static const double xs = 4;

  /// 8px — between closely related elements.
  static const double sm = 8;

  /// 16px — card internal padding, standard gap.
  static const double md = 16;

  /// 24px — screen horizontal padding (mobile).
  static const double lg = 24;

  /// 32px — between major sections.
  static const double xl = 32;

  /// 48px — large breathing room (Hero screens).
  static const double xxl = 48;

  /// 64px — extra-large spacing (landing hero sections).
  static const double xxxl = 64;

  /// 80px — maximum spacing (landing top/bottom breathing room).
  static const double xxxxl = 80;

  /// 32px — screen horizontal padding (tablet).
  static const double page = 32;

  // ── Convenience EdgeInsets ──

  /// Standard horizontal screen padding (mobile).
  static const screenH = lg;

  /// Standard card internal padding.
  static const cardPadding = md;
}
