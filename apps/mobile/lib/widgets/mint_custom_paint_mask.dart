// apps/mobile/lib/widgets/mint_custom_paint_mask.dart
//
// Default-deny wrapper around CustomPaint for nLPD compliance.
// sentry_flutter 9.14.0 privacy.maskAllText + maskAllImages do NOT cover
// CustomPaint (canvas-rendered pixels). MINT uses CustomPaint for charts
// rendering CHF / AVS / IBAN / ratios across Coach / Budget / Explorer.
//
// Rule (D-06): wrap EVERY financial-data CustomPaint in MintCustomPaintMask.
// Only chrome (logos, dividers, spacers) may opt-out via SentryUnmask —
// and every opt-out requires a commit message `unmask: <reason>`.
//
// Audit artefact: .planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md
// Phase 31 kill-gate (OBS-06). Prod sessionSampleRate stays 0.0 per D-01 Option C
// until the audit signs — this wrapper is the per-widget mitigation for
// error-only replays (onErrorSampleRate=1.0), where a crash can still attach
// a frame containing the broken financial surface.

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Wrap a financial-data CustomPaint for Sentry Session Replay masking.
///
/// Example:
/// ```dart
/// MintCustomPaintMask(
///   child: CustomPaint(painter: ConfidenceCirclePainter(score)),
/// )
/// ```
///
/// Behaviour:
/// - In release/profile builds with Sentry Replay capture active, the
///   wrapped subtree is marked for mask overlay (canvas pixels replaced
///   with a block in replay frames).
/// - In debug builds / zero-Sentry runs, `SentryMask` is a no-op
///   pass-through — it returns `child` as-is. This is fine: masking only
///   matters on recorded frames (staging/prod), and debug builds do not
///   capture replays in MINT's config (see main.dart D-01 Option C).
/// - The widget is a plain [StatelessWidget] wrapping `SentryMask`; this
///   keeps the dev-time widget tree readable and gives us a grep target
///   (`MintCustomPaintMask`) for Phase 34 lefthook lint extension.
///
/// Note on experimental marker: `SentryMask` is currently annotated
/// `@experimental` in sentry_flutter 9.14.0. We accept the stability risk
/// intentionally — the class IS the public wrapping primitive for
/// Session Replay canvas-mask, and the alternative (custom RenderObject
/// visitor) would be worse. The `ignore: experimental_member_use` below
/// is the sanctioned escape hatch per D-06 (default-deny CustomPaint).
// ignore: experimental_member_use
class MintCustomPaintMask extends StatelessWidget {
  const MintCustomPaintMask({super.key, required this.child});

  /// The subtree to mask in Session Replay. Typically a [CustomPaint]
  /// rendering financial data (charts, progress indicators, amount
  /// glyphs, IBAN / AVS visualisations).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // SentryMask marks the subtree as masked in Session Replay capture.
    // API note: sentry_flutter 9.14.0 exposes SentryMask via
    // `export 'src/screenshot/sentry_mask_widget.dart';` in sentry_flutter.dart
    // (verified against local pub-cache 2026-04-19). The widget takes the
    // child as a positional argument: `SentryMask(child)`.
    // ignore: experimental_member_use
    return SentryMask(child);
  }
}
