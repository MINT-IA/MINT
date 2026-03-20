/// FHS Thermometer — Sprint S54.
///
/// Hero widget for the Pulse screen displaying the daily Financial Health Score
/// as a WHOOP Recovery Score-inspired circular arc gauge.
///
/// Visual design:
///   - 270-degree arc with gradient color based on score thresholds
///   - Center: large score number (Montserrat bold) + level label + delta badge
///   - Animated spring curve (800ms) from 0 to score on first build
///   - CustomPainter for the arc (no external packages)
///
/// Color mapping (MintColors):
///   0-40  → scoreCritique (red)
///   40-60 → scoreAttention (yellow/orange)
///   60-80 → scoreExcellent (green)
///   80-100 → greenForest (dark green)
///
/// Sources: LAVS art. 21-29, LPP art. 14-16, LIFD art. 38.
/// Outil educatif — ne constitue pas un conseil financier (LSFin).
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/models/fhs_daily_score.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/pulse/fhs_delta_badge.dart';

/// Circular arc gauge showing the daily FHS score (0-100).
///
/// Intended as the hero widget at the top of the Pulse screen.
/// Renders a 270-degree arc with a gradient that shifts from red (critical)
/// through yellow (needs improvement) and green (good) to dark green (excellent).
class FhsThermometer extends StatefulWidget {
  /// Overall FHS score (0-100).
  final double score;

  /// WHOOP-inspired level derived from [score].
  final FhsLevel level;

  /// Score change vs yesterday (positive = improvement).
  final double deltaVsYesterday;

  /// Callback when widget is tapped (e.g., opens history sheet).
  final VoidCallback? onTap;

  const FhsThermometer({
    super.key,
    required this.score,
    required this.level,
    required this.deltaVsYesterday,
    this.onTap,
  });

  @override
  State<FhsThermometer> createState() => _FhsThermometerState();
}

class _FhsThermometerState extends State<FhsThermometer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _arcAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _arcAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // Spring-like overshoot
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(FhsThermometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Primary color for the current score.
  Color get _scoreColor {
    if (widget.score >= 80) return MintColors.greenForest;
    if (widget.score >= 60) return MintColors.scoreExcellent;
    if (widget.score >= 40) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  String _levelLabel(BuildContext context) {
    final l = S.of(context)!;
    return switch (widget.level) {
      FhsLevel.excellent => l.fhsLevelExcellent,
      FhsLevel.good => l.fhsLevelBon,
      FhsLevel.needsImprovement => l.fhsLevelAmeliorer,
      FhsLevel.critical => l.fhsLevelCritique,
    };
  }

  /// Derive [FhsTrend] from the delta value.
  /// Uses ±2.0 threshold (same as FinancialHealthScoreService.kFhsTrendThreshold)
  /// to avoid conflicting signals between service and widget.
  FhsTrend get _trend {
    if (widget.deltaVsYesterday > 2.0) return FhsTrend.up;
    if (widget.deltaVsYesterday < -2.0) return FhsTrend.down;
    return FhsTrend.stable;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Score de sant\u00e9 financi\u00e8re\u00a0: '
          '${widget.score.round()} sur 100. '
          'Niveau\u00a0: ${_levelLabel(context)}.',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 200,
          height: 230,
          child: AnimatedBuilder(
            animation: _arcAnimation,
            builder: (context, _) {
              // Bug fix: clamp to 0-100 to prevent easeOutBack overshoot showing >100.
              final displayScore =
                  (widget.score * _arcAnimation.value).round().clamp(0, 100);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Arc gauge
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          painter: _FhsArcPainter(
                            score: widget.score,
                            progress: _arcAnimation.value,
                          ),
                          size: const Size(200, 200),
                        ),
                        // Center content
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Large score number
                            Text(
                              '$displayScore',
                              style: MintTextStyles.displayLarge(color: _scoreColor).copyWith(fontSize: 52, height: 1.0),
                            ),
                            const SizedBox(height: 4),
                            // Level label
                            Text(
                              _levelLabel(context),
                              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            // Delta badge
                            FhsDeltaBadge(
                              delta: widget.deltaVsYesterday,
                              trend: _trend,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  FHS ARC CUSTOM PAINTER
// ────────────────────────────────────────────────────────────
//
//  270-degree arc with 4-stop gradient:
//    red (0) → yellow (40) → green (60) → dark green (100)
//  Background track in surface grey. Glow at arc tip.
// ────────────────────────────────────────────────────────────

class _FhsArcPainter extends CustomPainter {
  final double score;
  final double progress;

  _FhsArcPainter({
    required this.score,
    required this.progress,
  });

  // 4 color stops matching FHS level thresholds (MintColors)
  static const _gradientColors = [
    MintColors.scoreCritique, // 0%   — red
    MintColors.scoreAttention, // 40%  — yellow/orange
    MintColors.scoreExcellent, // 60%  — green
    MintColors.greenForest, // 100% — dark green
  ];
  static const _gradientStops = [0.0, 0.40, 0.60, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    const strokeWidth = 14.0;

    // Start angle: bottom-left (225 degrees = 0.75*pi from 3 o'clock)
    const startAngle = 0.75 * pi; // 135 degrees from east
    const totalSweep = 1.5 * pi; // 270 degrees

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // ── Background track ──
    final trackPaint = Paint()
      ..color = MintColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, startAngle, totalSweep, false, trackPaint);

    // ── Filled arc (animated) ──
    final scoreFraction = (score / 100.0).clamp(0.0, 1.0);
    final valueSweep = totalSweep * scoreFraction * progress;

    if (valueSweep < 0.001) return;

    // Build a SweepGradient that covers the full 270-degree arc with
    // the 4 FHS color stops.
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0.75 * pi,
        endAngle: 0.75 * pi + 1.5 * pi,
        colors: _gradientColors,
        stops: _gradientStops,
      ).createShader(arcRect);

    canvas.drawArc(arcRect, startAngle, valueSweep, false, fillPaint);

    // ── Glow at endpoint ──
    final endAngle = startAngle + valueSweep;
    final glowCenter = Offset(
      center.dx + radius * cos(endAngle),
      center.dy + radius * sin(endAngle),
    );

    // Determine tip color from score position
    final tipColor = _colorForScore(score * progress);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          tipColor.withValues(alpha: 0.35),
          tipColor.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: glowCenter, radius: 14),
      );
    canvas.drawCircle(glowCenter, 14, glowPaint);

    // Bright tip dot
    canvas.drawCircle(glowCenter, 4.5, Paint()..color = tipColor);
  }

  /// Interpolate color based on score position in the gradient.
  Color _colorForScore(double s) {
    final t = (s / 100.0).clamp(0.0, 1.0);
    // Find which segment of the gradient we're in
    for (int i = 0; i < _gradientStops.length - 1; i++) {
      if (t <= _gradientStops[i + 1]) {
        final segFrac = (t - _gradientStops[i]) /
            (_gradientStops[i + 1] - _gradientStops[i]);
        return Color.lerp(
            _gradientColors[i], _gradientColors[i + 1], segFrac)!;
      }
    }
    return _gradientColors.last;
  }

  @override
  bool shouldRepaint(covariant _FhsArcPainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.progress != progress;
  }
}
