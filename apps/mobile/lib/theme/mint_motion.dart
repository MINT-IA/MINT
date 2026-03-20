import 'package:flutter/animation.dart';

/// MINT Design System — Motion tokens.
///
/// Source of truth: `docs/MINT_UX_GRAAL_MASTERPLAN.md` §6 (Motion)
///
/// Principles:
/// - apparition douce
/// - transitions de couches
/// - graphes qui se dessinent calmement
/// - microparallax tres leger
///
/// Never:
/// - confetti
/// - bounce gadget
/// - suranimation
///
/// Usage:
/// ```dart
/// AnimatedContainer(
///   duration: MintMotion.standard,
///   curve: MintMotion.curveStandard,
///   // ...
/// )
/// ```
class MintMotion {
  MintMotion._();

  // ── Durations ──

  /// Quick micro-interactions (color change, opacity toggle).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions (card expand, slide, fade).
  static const Duration standard = Duration(milliseconds: 300);

  /// Slow, deliberate reveals (hero number, graph draw).
  static const Duration slow = Duration(milliseconds: 600);

  /// Page transitions.
  static const Duration page = Duration(milliseconds: 350);

  // ── Curves ──

  /// Standard ease-out for most UI transitions.
  static const Curve curveStandard = Curves.easeOutCubic;

  /// Deceleration for entering elements (slide in, fade in).
  static const Curve curveEnter = Curves.easeOutQuart;

  /// Acceleration for exiting elements (slide out, fade out).
  static const Curve curveExit = Curves.easeInCubic;

  /// Smooth spring for playful but controlled motion (graph redraw).
  static const Curve curveSpring = Curves.elasticOut;
}
