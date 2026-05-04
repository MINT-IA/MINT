/// MintTrameConfiance (MTC) — the single confidence rendering primitive for MINT.
///
/// Doctrine (locked, see `.planning/phases/04-p4-mtc-component-s4-migration/04-CONTEXT.md`):
///
///   * **D-01** — class name `MintTrameConfiance`, family acronym `MTC` in
///     code comments only. Lives in `widgets/trust/`.
///   * **D-02** — 4 named constructors: `.inline`, `.detail`, `.audio`, `.empty`.
///     `BloomStrategy` is required at every constructor (compile-time enforced).
///   * **D-03** — `BloomStrategy` co-located here, NOT in the voice cursor contract.
///   * **D-04** — Renders the WEAKEST axis only. No 4-bar visualization, no
///     headline number. A horizontal trame at fixed 4dp height encodes density.
///   * **D-05** — Default bloom: 250ms ease-out, opacity + scale.
///     `MediaQuery.disableAnimations` → 50ms opacity-only fallback.
///   * **D-06** — `audioTone` (VoiceLevel) only adapts the semantic label
///     phrasing variant. NEVER shifts colors. MTC does NOT call `resolveLevel()`.
///   * **D-08** — No public `score: double` getter. Compliance: prevents the
///     renderer from being weaponized for ranking surfaces.
///   * **D-10** — Zero hardcoded hex color literals. All colors via `MintColors.*Aaa`.
///   * **D-11** — `SemanticsService.announce` fires exactly once per
///     EnhancedConfidence reference change.
///
/// Visual grammar references (informs painter density + bloom timing):
/// NYT election needle (uncertainty bands), Apple Weather temperature ranges,
/// Things 3 / Linear microtypography, Arc bloom (200-300ms), Stripe Atlas
/// "not yet certain" states. NOT derived from VZ visual style — only the
/// confidence-as-doctrine concept is borrowed from VZ.
library mint_trame_confiance;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mint_mobile/widgets/mint_custom_paint_mask.dart';

import '../../l10n/app_localizations.dart' show S;
import '../../services/financial_core/confidence_scorer.dart';
import '../../services/voice/voice_cursor_contract.dart';
import '../../theme/colors.dart';

// ============================================================================
//  ConfidenceAxis — local enum (D-02 / MTC-02).
// ============================================================================

/// The 4 axes of [EnhancedConfidence] surfaced as a typed enum so
/// constructors like [MintTrameConfiance.empty] can identify the missing
/// axis without leaking a magic string.
enum ConfidenceAxis { completeness, accuracy, freshness, understanding }

// ============================================================================
//  BloomStrategy — D-03.
// ============================================================================

/// How the MTC bloom animation behaves on mount.
///
/// * [firstAppearance] — bloom every time the widget mounts fresh
///   (standalone surfaces, S4 detail, hero zones).
/// * [onlyIfTopOfList] — bloom only when `isTopOfList == true`. Feed
///   contexts (ContextualCard ranked home). 60ms stagger handled by parent.
/// * [never] — explicit opt-out. Used by reduced-motion-aware parents and
///   already-seen-this-session caching.
enum BloomStrategy { firstAppearance, onlyIfTopOfList, never }

/// Pure helper deciding whether the MTC bloom controller should run.
///
/// Returns `true` only when:
///   * `disableAnimations == false`, AND
///   * strategy is NOT [BloomStrategy.never], AND
///   * strategy is [BloomStrategy.firstAppearance], OR
///   * strategy is [BloomStrategy.onlyIfTopOfList] AND `isTopOfList == true`.
@visibleForTesting
bool shouldBloom({
  required BloomStrategy strategy,
  required bool isTopOfList,
  required bool disableAnimations,
}) {
  if (disableAnimations) return false;
  switch (strategy) {
    case BloomStrategy.never:
      return false;
    case BloomStrategy.firstAppearance:
      return true;
    case BloomStrategy.onlyIfTopOfList:
      return isTopOfList;
  }
}

// ============================================================================
//  Weakest-axis identification — D-04.
// ============================================================================

/// Deterministic priority order for ties: completeness > accuracy >
/// freshness > understanding. Matches D-09 test expectations.
ConfidenceAxis _weakestAxis(EnhancedConfidence c) {
  // Normalize to 0..1 (EnhancedConfidence stores 0..100).
  final values = <ConfidenceAxis, double>{
    ConfidenceAxis.completeness: c.completeness,
    ConfidenceAxis.accuracy: c.accuracy,
    ConfidenceAxis.freshness: c.freshness,
    ConfidenceAxis.understanding: c.understanding,
  };
  ConfidenceAxis weakest = ConfidenceAxis.completeness;
  double weakestValue = values[ConfidenceAxis.completeness]!;
  // Iterate in deterministic order so ties resolve to the earliest axis.
  for (final axis in ConfidenceAxis.values) {
    final v = values[axis]!;
    if (v < weakestValue) {
      weakest = axis;
      weakestValue = v;
    }
  }
  return weakest;
}

/// Returns the value (0..100 scale) of the weakest axis.
double _weakestValue(EnhancedConfidence c) {
  final axis = _weakestAxis(c);
  switch (axis) {
    case ConfidenceAxis.completeness:
      return c.completeness;
    case ConfidenceAxis.accuracy:
      return c.accuracy;
    case ConfidenceAxis.freshness:
      return c.freshness;
    case ConfidenceAxis.understanding:
      return c.understanding;
  }
}

// ============================================================================
//  oneLineConfidenceSummary — D-04 / MTC-05.
// ============================================================================

/// Returns the one-line summary for the WEAKEST axis only. Anti-shame:
/// MINT is the subject of any limitation phrasing.
///
/// When [l10n] is null (unit-test mode), returns the raw ARB key so tests
/// can assert key resolution without a `BuildContext`. When non-null,
/// returns the resolved localized string.
///
/// Per D-06: when [audioTone] is provided, the phrasing variant adapts in
/// future iterations (N1/N2 calmer, N4/N5 more direct). Phase 4 ships the
/// neutral N3 variant only — the parameter exists for API stability.
String oneLineConfidenceSummary(
  EnhancedConfidence confidence, {
  S? l10n,
  // ignore: unused_element_parameter
  // Reason: D-06 API-stability stub. The audioTone axis will drive
  // N1/N2 calmer vs N4/N5 more direct phrasing in a future iteration;
  // Phase 4 ships the neutral N3 variant only. Keeping the parameter
  // now avoids a breaking signature change at every call site later.
  // Tracked: docs/KNOWN_GAPS_v2.2.md Cat 3 (P2 — unjustified ignore).
  VoiceLevel? audioTone,
}) {
  final axis = _weakestAxis(confidence);
  if (l10n == null) {
    switch (axis) {
      case ConfidenceAxis.completeness:
        return 'mtcSummaryWeakCompleteness';
      case ConfidenceAxis.accuracy:
        return 'mtcSummaryWeakAccuracy';
      case ConfidenceAxis.freshness:
        return 'mtcSummaryWeakFreshness';
      case ConfidenceAxis.understanding:
        return 'mtcSummaryWeakUnderstanding';
    }
  }
  switch (axis) {
    case ConfidenceAxis.completeness:
      return l10n.mtcSummaryWeakCompleteness;
    case ConfidenceAxis.accuracy:
      return l10n.mtcSummaryWeakAccuracy;
    case ConfidenceAxis.freshness:
      return l10n.mtcSummaryWeakFreshness;
    case ConfidenceAxis.understanding:
      return l10n.mtcSummaryWeakUnderstanding;
  }
}

// ============================================================================
//  _TramePainter — D-04 + D-10.
// ============================================================================

/// Three deterministic visual states.
///
/// `sparse` is never rendered: the inline factory redirects to `.empty`
/// when the weakest axis falls below 0.4.
@visibleForTesting
enum TrameDensity { dense, medium, sparse }

@visibleForTesting
TrameDensity densityForWeakest(double weakestValue0to100) {
  final v = (weakestValue0to100 / 100.0).clamp(0.0, 1.0);
  if (v >= 0.7) return TrameDensity.dense;
  if (v >= 0.4) return TrameDensity.medium;
  return TrameDensity.sparse;
}

class _TramePainter extends CustomPainter {
  _TramePainter({required this.density, required this.progress});

  final TrameDensity density;
  final double progress; // 0..1, drives bloom width fade-in

  @override
  void paint(Canvas canvas, Size size) {
    // Track is a 4dp horizontal strip. Color comes from AAA tokens only.
    final Color color = density == TrameDensity.dense
        ? MintColors.textMutedAaa
        : MintColors.textSecondaryAaa;
    final Paint base = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final double width = size.width * progress.clamp(0.0, 1.0);
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(rrect, base);
    // Density encoding: dense → 1 layer (solid). Medium → 1 layer at lower alpha
    // (already encoded by token swap). No 4-bar split — D-04 hard rule.
  }

  @override
  bool shouldRepaint(covariant _TramePainter old) =>
      old.density != density || old.progress != progress;
}

// ============================================================================
//  MintTrameConfiance — D-02.
// ============================================================================

class MintTrameConfiance extends StatefulWidget {
  /// Test-only counter incremented every time `SemanticsService.announce`
  /// is invoked by an MTC instance. Reset between tests via [debugReset].
  @visibleForTesting
  static int debugAnnounceCount = 0;

  /// Resets test-only counters. Call in `setUp`.
  @visibleForTesting
  static void debugReset() {
    debugAnnounceCount = 0;
  }

  /// Internal kind discriminator. Tests assert this via [debugKind].
  final MtcKind _kind;

  /// Test-only accessor for the constructor variant.
  @visibleForTesting
  MtcKind get debugKind => _kind;

  final EnhancedConfidence? confidence;
  final BloomStrategy bloomStrategy;
  final VoiceLevel? audioTone;
  final bool isTopOfList;
  final List<String> hypotheses;
  final ConfidenceAxis? missingAxis;
  final String? enrichCtaKey;

  const MintTrameConfiance._({
    required MtcKind kind,
    required this.bloomStrategy,
    this.confidence,
    this.audioTone,
    this.isTopOfList = false,
    this.hypotheses = const [],
    this.missingAxis,
    this.enrichCtaKey,
    super.key,
  }) : _kind = kind;

  /// Inline rendering: trame + one-line summary. Factory redirect to
  /// [MintTrameConfiance.empty] when weakest axis < 0.4 (sparse triggers
  /// the empty state per D-04).
  factory MintTrameConfiance.inline({
    required EnhancedConfidence confidence,
    required BloomStrategy bloomStrategy,
    VoiceLevel? audioTone,
    bool isTopOfList = false,
    Key? key,
  }) {
    final density = densityForWeakest(_weakestValue(confidence));
    if (density == TrameDensity.sparse) {
      return MintTrameConfiance.empty(
        missingAxis: _weakestAxis(confidence),
        enrichCtaKey: 'mtcSummaryWeak${_weakestAxisSuffix(confidence)}',
        key: key,
      );
    }
    return MintTrameConfiance._(
      kind: MtcKind.inline,
      confidence: confidence,
      bloomStrategy: bloomStrategy,
      audioTone: audioTone,
      isTopOfList: isTopOfList,
      key: key,
    );
  }

  /// Detail rendering: inline + hypotheses footer (max 3, MTC-07).
  factory MintTrameConfiance.detail({
    required EnhancedConfidence confidence,
    required BloomStrategy bloomStrategy,
    required List<String> hypotheses,
    VoiceLevel? audioTone,
    Key? key,
  }) {
    assert(
      hypotheses.length <= 3,
      'MintTrameConfiance.detail: hypotheses.length must be ≤ 3 (MTC-07).',
    );
    return MintTrameConfiance._(
      kind: MtcKind.detail,
      confidence: confidence,
      bloomStrategy: bloomStrategy,
      audioTone: audioTone,
      hypotheses: hypotheses,
      key: key,
    );
  }

  /// Audio rendering: semantic label only. liveRegion: true.
  factory MintTrameConfiance.audio({
    required EnhancedConfidence confidence,
    required VoiceLevel audioTone,
    required BloomStrategy bloomStrategy,
    Key? key,
  }) {
    return MintTrameConfiance._(
      kind: MtcKind.audio,
      confidence: confidence,
      audioTone: audioTone,
      bloomStrategy: bloomStrategy,
      key: key,
    );
  }

  /// Empty state: missing-data prompt with enrichment CTA. Semantically a button.
  factory MintTrameConfiance.empty({
    required ConfidenceAxis missingAxis,
    required String enrichCtaKey,
    Key? key,
  }) {
    return MintTrameConfiance._(
      kind: MtcKind.empty,
      bloomStrategy: BloomStrategy.never,
      missingAxis: missingAxis,
      enrichCtaKey: enrichCtaKey,
      key: key,
    );
  }

  @override
  State<MintTrameConfiance> createState() => _MintTrameConfianceState();
}

/// Public enum (test-only consumer) discriminating the MTC variant.
enum MtcKind { inline, detail, audio, empty }

String _weakestAxisSuffix(EnhancedConfidence c) {
  switch (_weakestAxis(c)) {
    case ConfidenceAxis.completeness:
      return 'Completeness';
    case ConfidenceAxis.accuracy:
      return 'Accuracy';
    case ConfidenceAxis.freshness:
      return 'Freshness';
    case ConfidenceAxis.understanding:
      return 'Understanding';
  }
}

class _MintTrameConfianceState extends State<MintTrameConfiance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;
  Animation<double>? _scale;
  bool _reducedMotion = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _setupAnimation();
    _maybeAnnounce(initial: true);
  }

  void _setupAnimation() {
    final shouldAnim = shouldBloom(
      strategy: widget.bloomStrategy,
      isTopOfList: widget.isTopOfList,
      disableAnimations: _reducedMotion,
    );

    if (widget.bloomStrategy == BloomStrategy.never && !_reducedMotion) {
      // Never bloom: no controller at all, render in final state.
      return;
    }
    if (_reducedMotion && widget.bloomStrategy != BloomStrategy.never) {
      // Reduced-motion: 50ms opacity-only linear fade.
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 50),
      );
      _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.linear),
      );
      _scale = null; // explicit: no scale tween
      _controller!.forward();
      return;
    }
    if (shouldAnim) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      );
      _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
      );
      _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
      );
      _controller!.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MintTrameConfiance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.confidence, widget.confidence)) {
      _maybeAnnounce(initial: false);
    }
  }

  void _maybeAnnounce({required bool initial}) {
    if (widget._kind == MtcKind.empty) return;
    final c = widget.confidence;
    if (c == null) return;
    // Build a localized announcement string. Fall back to a constant if
    // localizations aren't available yet (very early frames in tests).
    final l10n = S.of(context);
    final label = l10n != null
        ? oneLineConfidenceSummary(c, l10n: l10n, audioTone: widget.audioTone)
        : 'mtc-confidence';
    // Use `SemanticsService.announce` — the stable API on Flutter 3.27.x
    // pinned by CI. `sendAnnouncement(view, ...)` only exists on newer
    // Flutter versions and breaks the build under 3.27.4.
    SemanticsService.announce(label, TextDirection.ltr);
    MintTrameConfiance.debugAnnounceCount++;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget._kind) {
      case MtcKind.inline:
        return _buildInline(context);
      case MtcKind.detail:
        return _buildDetail(context);
      case MtcKind.audio:
        return _buildAudio(context);
      case MtcKind.empty:
        return _buildEmpty(context);
    }
  }

  Widget _wrapBloom(Widget child) {
    final controller = _controller;
    if (controller == null) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final op = _opacity?.value ?? 1.0;
        final sc = _scale?.value ?? 1.0;
        Widget w = Opacity(opacity: op, child: child);
        if (_scale != null) {
          w = Transform.scale(scale: sc, alignment: Alignment.centerLeft, child: w);
        }
        return w;
      },
    );
  }

  Widget _buildInline(BuildContext context) {
    final l10n = S.of(context);
    final c = widget.confidence!;
    final density = densityForWeakest(_weakestValue(c));
    final summary = l10n != null
        ? oneLineConfidenceSummary(c, l10n: l10n, audioTone: widget.audioTone)
        : oneLineConfidenceSummary(c);
    final controller = _controller;
    return Semantics(
      liveRegion: false,
      label: summary,
      child: _wrapBloom(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 4,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: controller ?? const AlwaysStoppedAnimation(1.0),
                builder: (_, __) => MintCustomPaintMask(
                  child: CustomPaint(
                    painter: _TramePainter(
                      density: density,
                      progress: controller == null ? 1.0 : (_opacity?.value ?? 1.0),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                letterSpacing: 0.1,
                color: MintColors.textSecondaryAaa,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final l10n = S.of(context);
    final c = widget.confidence!;
    final density = densityForWeakest(_weakestValue(c));
    final summary = l10n != null
        ? oneLineConfidenceSummary(c, l10n: l10n, audioTone: widget.audioTone)
        : oneLineConfidenceSummary(c);
    return Semantics(
      liveRegion: false,
      label: summary,
      child: _wrapBloom(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 4,
              width: double.infinity,
              child: MintCustomPaintMask(
                child: CustomPaint(
                  painter: _TramePainter(density: density, progress: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                letterSpacing: 0.1,
                color: MintColors.textSecondaryAaa,
              ),
            ),
            if (widget.hypotheses.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final h in widget.hypotheses)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '— $h',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: MintColors.textMutedAaa,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudio(BuildContext context) {
    final l10n = S.of(context);
    final c = widget.confidence!;
    final summary = l10n != null
        ? oneLineConfidenceSummary(c, l10n: l10n, audioTone: widget.audioTone)
        : oneLineConfidenceSummary(c);
    return Semantics(
      liveRegion: true,
      label: summary,
      child: _wrapBloom(
        // Visually invisible-but-present 1dp box; this is the audio surface.
        SizedBox(
          height: 1,
          child: Text(
            summary,
            style: const TextStyle(
              fontSize: 11,
              color: MintColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    // Empty state is interactive (button semantics) but the visible UI is
    // a calm microtypo line. The CTA key is resolved by the consumer; we
    // render the key string itself when no localizations match it (test mode).
    final l10n = S.of(context);
    final missing = widget.missingAxis ?? ConfidenceAxis.completeness;
    String label;
    if (l10n != null) {
      switch (missing) {
        case ConfidenceAxis.completeness:
          label = l10n.mtcSummaryWeakCompleteness;
          break;
        case ConfidenceAxis.accuracy:
          label = l10n.mtcSummaryWeakAccuracy;
          break;
        case ConfidenceAxis.freshness:
          label = l10n.mtcSummaryWeakFreshness;
          break;
        case ConfidenceAxis.understanding:
          label = l10n.mtcSummaryWeakUnderstanding;
          break;
      }
    } else {
      label = widget.enrichCtaKey ?? 'mtcEnrich';
    }
    return Semantics(
      liveRegion: false,
      button: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: MintColors.textMutedAaa,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
