// apps/mobile/lib/widgets/aujourdhui/confidence_evolution_card.dart
//
// D5 — North Star « évolution visible ». A sober lucidity curve at the head of
// the « Ton histoire » section (aujourdhui_screen): « toi d'avant vs toi
// maintenant », measured in understanding, not money.
//
// Reads the local confidence history persisted by [ConfidenceHistoryService]
// (socle, PR #1168). The service stores the RAW combined score per day; this
// widget renders a MONOTONE non-decreasing series (running max) so a passive
// user never sees the curve regress by mere inaction — combined can drop as
// freshness decays, but that is a store concern, not a presentation one
// (D5 exit criterion + benchmark principle 5). Monotonicity lives here, at the
// render, so the store stays honest and flexible.

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart' show S;
import '../../models/confidence_point.dart';
import '../../services/confidence/confidence_history_service.dart';
import '../../theme/colors.dart';
import '../../theme/mint_text_styles.dart';
import '../mint_custom_paint_mask.dart';

/// Triggers that name a milestone. A passive `profile_load` capture (the curve
/// origin) is never a milestone — the curve names achievements, never absence
/// (benchmark principles 6-8, anti-shame).
const Set<String> _kMilestoneTriggers = {'document_scan', 'check_in'};

/// Running-max of the combined score across chronological [points].
///
/// Guarantees a non-decreasing series so inaction never shows a drop (D5 exit
/// criterion — benchmark principle 5). The socle stores the raw combined; the
/// monotone shape is a presentation decision carried here.
@visibleForTesting
List<double> confidenceRunningMax(List<ConfidencePoint> points) {
  final out = <double>[];
  // Start at 0 (combined is a 0-100 index; the socle rejects <= 0 and
  // non-finite before persisting). A non-finite value never raises the max,
  // so the output is always finite — no NaN/Infinity can reach round().
  var max = 0.0;
  for (final p in points) {
    final c = p.combined;
    if (c.isFinite && c > max) max = c;
    out.add(max);
  }
  return out;
}

/// The most recent point produced by an explicit user action — the named
/// milestone. Returns `null` when the history holds only passive captures.
@visibleForTesting
ConfidencePoint? namedMilestone(List<ConfidencePoint> points) {
  for (var i = points.length - 1; i >= 0; i--) {
    if (_kMilestoneTriggers.contains(points[i].trigger)) return points[i];
  }
  return null;
}

/// Sober lucidity-evolution card. Self-loads the confidence history unless
/// [points] is injected (test seam).
///
/// States (design 2026-07-31-d5-confidence-curve.md):
///   * 0 points  → renders nothing (no empty section, D4).
///   * 1 point   → a single marker + calm invite, no line.
///   * ≥ 2 points → the monotone curve + current value + one named milestone.
class ConfidenceEvolutionCard extends StatefulWidget {
  const ConfidenceEvolutionCard({super.key, this.points});

  /// Injected points (test seam). When null, the card self-loads from
  /// [ConfidenceHistoryService.load] (oldest first).
  final List<ConfidencePoint>? points;

  @override
  State<ConfidenceEvolutionCard> createState() =>
      _ConfidenceEvolutionCardState();
}

class _ConfidenceEvolutionCardState extends State<ConfidenceEvolutionCard> {
  List<ConfidencePoint>? _points;

  @override
  void initState() {
    super.initState();
    if (widget.points != null) {
      _points = widget.points;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final pts = await ConfidenceHistoryService.load();
    if (!mounted) return;
    setState(() => _points = pts);
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    // Loading OR 0 points → render nothing. No empty section (D4).
    if (points == null || points.isEmpty) return const SizedBox.shrink();

    final l10n = S.of(context)!;
    return Padding(
      key: const Key('confidence-evolution-card'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.craie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.borderSubtle),
        ),
        child: points.length == 1
            ? _buildSingle(l10n)
            : _buildCurve(context, l10n, points),
      ),
    );
  }

  /// 1-point state: a calm marker + invite. A single point cannot draw a line.
  Widget _buildSingle(S l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.confidenceCurveTitle,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          key: const Key('confidence-evolution-single'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: MintColors.mintForest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.confidenceCurveSinglePoint,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ≥ 2 points: the monotone curve + current value + one named milestone.
  Widget _buildCurve(BuildContext context, S l10n, List<ConfidencePoint> points) {
    final series = confidenceRunningMax(points);
    final start = series.first.round();
    final latest = series.last.round();
    final milestone = namedMilestone(points);
    final milestoneIndex = milestone == null ? null : points.indexOf(milestone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.confidenceCurveTitle,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$latest',
                  key: const Key('confidence-evolution-value'),
                  style: MintTextStyles.headlineSmall(
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  l10n.confidenceCurveNow,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMutedAaa,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // The curve. Its Semantics carries the trend in words — the painted
        // line alone is invisible to a screen reader. No root Semantics merge
        // on the card (keeps each label its own node; AX-collapse-safe).
        Semantics(
          label: l10n.confidenceCurveTrendSemantics(
            start.toString(),
            latest.toString(),
          ),
          child: SizedBox(
            key: const Key('confidence-evolution-curve'),
            height: 64,
            width: double.infinity,
            child: MintCustomPaintMask(
              child: CustomPaint(
                painter: _ConfidenceCurvePainter(
                  series: series,
                  milestoneIndex: milestoneIndex,
                ),
              ),
            ),
          ),
        ),
        if (milestone != null) ...[
          const SizedBox(height: 16),
          Text(
            _milestoneLabel(context, l10n, milestone),
            key: const Key('confidence-evolution-milestone'),
            style: MintTextStyles.labelMedium(color: MintColors.textMutedAaa),
          ),
        ],
      ],
    );
  }

  String _milestoneLabel(BuildContext context, S l10n, ConfidencePoint m) {
    final date = MaterialLocalizations.of(context).formatShortMonthDay(m.date);
    switch (m.trigger) {
      case 'check_in':
        return l10n.confidenceCurveMilestoneCheckin(date);
      case 'document_scan':
      default:
        return l10n.confidenceCurveMilestoneScan(date);
    }
  }
}

/// Paints the monotone lucidity curve on a fixed 0-100 y-scale (honest: a
/// passive user's flat running-max reads as a steady line, not a fabricated
/// climb). One line, one endpoint accent, one optional milestone tick — no
/// axis, no grid (benchmark principle 11, « l'air est une structure »).
class _ConfidenceCurvePainter extends CustomPainter {
  _ConfidenceCurvePainter({required this.series, this.milestoneIndex});

  /// Running-max series, 0-100, non-decreasing, length >= 2.
  final List<double> series;

  /// Index (into [series]) of the named milestone, or null.
  final int? milestoneIndex;

  static const double _vPad = 8;

  Offset _pointFor(int i, Size size) {
    final n = series.length;
    final dx = n <= 1 ? size.width / 2 : (i / (n - 1)) * size.width;
    final v = (series[i] / 100.0).clamp(0.0, 1.0);
    final usableH = size.height - 2 * _vPad;
    final dy = _vPad + (1 - v) * usableH;
    return Offset(dx, dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;
    final pts = [for (var i = 0; i < series.length; i++) _pointFor(i, size)];

    // Faint area fill under the line — a whisper of body, very low alpha.
    final fill = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(pts.last.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = MintColors.primary.withValues(alpha: 0.05)
        ..style = PaintingStyle.fill,
    );

    // The line — the single confidence-color vocabulary (anthracite ink, the
    // affordance color already used by the confidence card). No level gradient.
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = MintColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Milestone tick — a discreet hollow ring; it is named in text below.
    final mi = milestoneIndex;
    if (mi != null && mi >= 0 && mi < pts.length) {
      final m = pts[mi];
      canvas
        ..drawCircle(
          m,
          4,
          Paint()
            ..color = MintColors.craie
            ..style = PaintingStyle.fill,
        )
        ..drawCircle(
          m,
          4,
          Paint()
            ..color = MintColors.textMutedAaa
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }

    // Endpoint dot — « toi maintenant ». The single positive accent
    // (mintForest, used sparingly per its token doc), haloed in craie so it
    // reads on the line.
    final end = pts.last;
    canvas
      ..drawCircle(
        end,
        6,
        Paint()
          ..color = MintColors.craie
          ..style = PaintingStyle.fill,
      )
      ..drawCircle(
        end,
        4,
        Paint()
          ..color = MintColors.mintForest
          ..style = PaintingStyle.fill,
      );
  }

  @override
  bool shouldRepaint(covariant _ConfidenceCurvePainter old) =>
      !listEquals(old.series, series) || old.milestoneIndex != milestoneIndex;
}
