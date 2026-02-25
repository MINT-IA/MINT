import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Graphique en eventail (fan/ribbon chart) — projection stochastique
/// du revenu de retraite sur 25-30 ans.
///
/// Affiche 5 bandes de percentiles (P10, P25, P50, P75, P90) rayonnant
/// depuis le point de depart a la retraite, avec une carte de synthese
/// en dessous.
///
/// Couleurs :
///   - P10-P90 : MintColors.primary, alpha 0.12
///   - P25-P75 : MintColors.primary, alpha 0.25
///   - P50     : MintColors.primary, trait plein 2px
///   - Ligne de reference : amber, pointille
///
/// References : outil pedagogique (LSFin). Ne constitue pas un conseil.
class MonteCarloChart extends StatelessWidget {
  /// Resultat complet de la simulation Monte Carlo.
  final MonteCarloResult result;

  /// Revenu mensuel actuel (optionnel) — affiche une ligne de reference.
  final double? currentMonthlyIncome;

  const MonteCarloChart({
    super.key,
    required this.result,
    this.currentMonthlyIncome,
  });

  @override
  Widget build(BuildContext context) {
    if (result.projection.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre ─────────────────────────────────────────────
        Text(
          'Projection stochastique',
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${result.numSimulations} simulations avec rendements aleatoires',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // ── Chart ─────────────────────────────────────────────
        SizedBox(
          height: 260,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, 260),
                painter: _MonteCarloFanPainter(
                  points: result.projection,
                  currentMonthlyIncome: currentMonthlyIncome,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // ── Legende ───────────────────────────────────────────
        _buildLegend(),
        const SizedBox(height: 16),

        // ── Carte de synthese ─────────────────────────────────
        _buildSummaryCard(),
        const SizedBox(height: 12),

        // ── Disclaimer ────────────────────────────────────────
        Text(
          'Les rendements passes ne presagent pas les rendements '
          'futurs. Simulation a titre pedagogique (LSFin).',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  LEGEND
  // ════════════════════════════════════════════════════════════════

  Widget _buildLegend() {
    final items = <Widget>[
      _legendItem(
        'P10\u2013P90',
        MintColors.primary.withValues(alpha: 0.12),
        border: MintColors.primary.withValues(alpha: 0.25),
      ),
      _legendItem(
        'P25\u2013P75',
        MintColors.primary.withValues(alpha: 0.25),
        border: MintColors.primary.withValues(alpha: 0.40),
      ),
      _legendItem('Mediane (P50)', MintColors.primary, isLine: true),
    ];

    if (currentMonthlyIncome != null) {
      items.add(_legendItem(
        'Revenu actuel',
        const Color(0xFFF59E0B),
        isLine: true,
        isDashed: true,
      ));
    }

    return Wrap(spacing: 14, runSpacing: 6, children: items);
  }

  Widget _legendItem(
    String label,
    Color color, {
    Color? border,
    bool isLine = false,
    bool isDashed = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          SizedBox(
            width: 16,
            height: 10,
            child: CustomPaint(
              painter: _LegendLinePainter(
                color: color,
                isDashed: isDashed,
              ),
            ),
          )
        else
          Container(
            width: 16,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.circular(2),
              border: border != null
                  ? Border.all(color: border, width: 0.5)
                  : null,
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SUMMARY CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildSummaryCard() {
    final ruinPct = (result.ruinProbability * 100).round();

    // Color coding for ruin probability
    final Color ruinColor;
    if (result.ruinProbability < 0.15) {
      ruinColor = MintColors.success;
    } else if (result.ruinProbability < 0.30) {
      ruinColor = MintColors.warning;
    } else {
      ruinColor = MintColors.error;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.circular(12),
        side: const BorderSide(color: MintColors.lightBorder, width: 1),
      ),
      color: MintColors.cardGround,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            // ── Mediane a l'age de retraite ────────────────
            _summaryRow(
              'Mediane a ${result.retirementAge} ans',
              '${_formatChf(result.medianAt65)}/mois',
            ),
            const SizedBox(height: 10),

            // ── Intervalle probable ─────────────────────────
            _summaryRow(
              'Intervalle probable\n(P10 \u2014 P90)',
              '${_formatChf(result.p10At65)} \u2014 ${_formatChf(result.p90At65)}',
            ),
            const SizedBox(height: 10),

            // ── Risque d'epuisement ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    "Risque d'epuisement du\ncapital avant 90 ans",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$ruinPct%',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ruinColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: _buildRuinBar(ruinPct, ruinColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  /// Mini horizontal bar for ruin probability visualization.
  Widget _buildRuinBar(int pct, Color color) {
    return ClipRRect(
      borderRadius: const BorderRadius.circular(3),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            // Background track
            Container(
              decoration: BoxDecoration(
                color: MintColors.lightBorder,
                borderRadius: const BorderRadius.circular(3),
              ),
            ),
            // Filled portion
            FractionallySizedBox(
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  NUMBER FORMATTING
  // ════════════════════════════════════════════════════════════════

  /// Swiss formatting: apostrophe thousands separator.
  static String _formatChf(double amount) {
    final rounded = amount.round().abs();
    final formatted = rounded.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => "${m[1]}'",
    );
    return "CHF\u00A0$formatted";
  }
}

// ════════════════════════════════════════════════════════════════════
//  CUSTOM PAINTER — Fan/ribbon chart
// ════════════════════════════════════════════════════════════════════

class _MonteCarloFanPainter extends CustomPainter {
  final List<MonteCarloPoint> points;
  final double? currentMonthlyIncome;

  _MonteCarloFanPainter({
    required this.points,
    this.currentMonthlyIncome,
  });

  // ── Layout constants ─────────────────────────────────────────
  static const double _leftPadding = 68.0; // Space for Y-axis labels
  static const double _rightPadding = 12.0;
  static const double _topPadding = 8.0;
  static const double _bottomPadding = 28.0; // Space for X-axis labels

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const chartLeft = _leftPadding;
    final chartRight = size.width - _rightPadding;
    const chartTop = _topPadding;
    final chartBottom = size.height - _bottomPadding;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // ── Determine Y scale ─────────────────────────────────
    double yMin = double.infinity;
    double yMax = double.negativeInfinity;
    for (final p in points) {
      yMin = min(yMin, p.p10);
      yMax = max(yMax, p.p90);
    }

    // Include current income in scale if provided
    if (currentMonthlyIncome != null) {
      yMin = min(yMin, currentMonthlyIncome!);
      yMax = max(yMax, currentMonthlyIncome!);
    }

    // Add 10% padding to scale
    final yRange = yMax - yMin;
    yMin = (yMin - yRange * 0.10).clamp(0, double.infinity);
    yMax = yMax + yRange * 0.10;
    if (yMax <= yMin) yMax = yMin + 1000; // safety

    // ── Determine X scale ─────────────────────────────────
    final ageMin = points.first.age;
    final ageMax = points.last.age;
    final ageRange = ageMax - ageMin;
    if (ageRange <= 0) return;

    // ── Helper closures ───────────────────────────────────
    double xForAge(int age) {
      return chartLeft + (age - ageMin) / ageRange * chartWidth;
    }

    double yForValue(double value) {
      return chartBottom - (value - yMin) / (yMax - yMin) * chartHeight;
    }

    // ── Grid lines ────────────────────────────────────────
    _drawGridLines(canvas, size, chartLeft, chartRight, chartTop, chartBottom,
        yMin, yMax, yForValue);

    // ── P10-P90 band ──────────────────────────────────────
    _drawBand(
      canvas: canvas,
      points: points,
      xForAge: xForAge,
      yForValue: yForValue,
      getLower: (p) => p.p10,
      getUpper: (p) => p.p90,
      color: MintColors.primary.withValues(alpha: 0.12),
    );

    // ── P25-P75 band ──────────────────────────────────────
    _drawBand(
      canvas: canvas,
      points: points,
      xForAge: xForAge,
      yForValue: yForValue,
      getLower: (p) => p.p25,
      getUpper: (p) => p.p75,
      color: MintColors.primary.withValues(alpha: 0.25),
    );

    // ── P50 median line ───────────────────────────────────
    _drawPercentileLine(
      canvas: canvas,
      points: points,
      xForAge: xForAge,
      yForValue: yForValue,
      getValue: (p) => p.p50,
      color: MintColors.primary,
      strokeWidth: 2.0,
    );

    // ── Current income reference line ─────────────────────
    if (currentMonthlyIncome != null) {
      _drawReferenceLine(
        canvas: canvas,
        value: currentMonthlyIncome!,
        yForValue: yForValue,
        chartLeft: chartLeft,
        chartRight: chartRight,
      );
    }

    // ── X-axis labels ─────────────────────────────────────
    _drawXAxisLabels(canvas, size, chartBottom, ageMin, ageMax, xForAge);

    // ── Percentile labels on right edge ───────────────────
    _drawPercentileLabels(canvas, chartRight, yForValue);
  }

  // ── Grid lines with Y-axis labels ───────────────────────────

  void _drawGridLines(
    Canvas canvas,
    Size size,
    double chartLeft,
    double chartRight,
    double chartTop,
    double chartBottom,
    double yMin,
    double yMax,
    double Function(double) yForValue,
  ) {
    final gridPaint = Paint()
      ..color = MintColors.lightBorder.withValues(alpha: 0.6)
      ..strokeWidth = 0.5;

    // Determine nice grid intervals
    final range = yMax - yMin;
    final rawStep = range / 5;
    final step = _niceStep(rawStep);

    final firstTick = (yMin / step).ceil() * step;

    for (double v = firstTick; v <= yMax; v += step) {
      final y = yForValue(v);
      if (y < chartTop || y > chartBottom) continue;

      // Grid line
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        gridPaint,
      );

      // Y-axis label
      final label = _formatAxisChf(v);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - tp.height / 2));
    }
  }

  // ── Draw a shaded band between two percentile lines ─────────

  void _drawBand({
    required Canvas canvas,
    required List<MonteCarloPoint> points,
    required double Function(int) xForAge,
    required double Function(double) yForValue,
    required double Function(MonteCarloPoint) getLower,
    required double Function(MonteCarloPoint) getUpper,
    required Color color,
  }) {
    if (points.length < 2) return;

    final path = Path();

    // Upper edge: left to right
    path.moveTo(xForAge(points.first.age), yForValue(getUpper(points.first)));
    for (int i = 1; i < points.length; i++) {
      path.lineTo(xForAge(points[i].age), yForValue(getUpper(points[i])));
    }

    // Lower edge: right to left
    for (int i = points.length - 1; i >= 0; i--) {
      path.lineTo(xForAge(points[i].age), yForValue(getLower(points[i])));
    }

    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // ── Draw a single percentile line ───────────────────────────

  void _drawPercentileLine({
    required Canvas canvas,
    required List<MonteCarloPoint> points,
    required double Function(int) xForAge,
    required double Function(double) yForValue,
    required double Function(MonteCarloPoint) getValue,
    required Color color,
    double strokeWidth = 1.5,
  }) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(xForAge(points.first.age), yForValue(getValue(points.first)));
    for (int i = 1; i < points.length; i++) {
      path.lineTo(xForAge(points[i].age), yForValue(getValue(points[i])));
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  // ── Current income reference line (dashed, amber) ───────────

  void _drawReferenceLine({
    required Canvas canvas,
    required double value,
    required double Function(double) yForValue,
    required double chartLeft,
    required double chartRight,
  }) {
    const color = Color(0xFFF59E0B);
    final y = yForValue(value);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    // Dashed line
    const dashLen = 6.0;
    const gapLen = 4.0;
    double currentX = chartLeft;
    while (currentX < chartRight) {
      final segEnd = min(currentX + dashLen, chartRight);
      canvas.drawLine(Offset(currentX, y), Offset(segEnd, y), paint);
      currentX = segEnd + gapLen;
    }

    // Small label on right
    final label = _formatAxisChf(value);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background pill for readability
    final labelX = chartRight - tp.width - 4;
    final labelY = y - tp.height - 3;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelX - 3, labelY - 1, tp.width + 6, tp.height + 2),
      const Radius.circular(3),
    );
    canvas.drawRRect(bgRect, Paint()..color = Colors.white.withValues(alpha: 0.85));
    tp.paint(canvas, Offset(labelX, labelY));
  }

  // ── X-axis labels (ages) ────────────────────────────────────

  void _drawXAxisLabels(
    Canvas canvas,
    Size size,
    double chartBottom,
    int ageMin,
    int ageMax,
    double Function(int) xForAge,
  ) {
    // Determine label interval based on range
    final range = ageMax - ageMin;
    final int interval;
    if (range <= 10) {
      interval = 1;
    } else if (range <= 20) {
      interval = 2;
    } else {
      interval = 5;
    }

    final firstLabel =
        ((ageMin / interval).ceil() * interval).clamp(ageMin, ageMax);

    for (int age = firstLabel; age <= ageMax; age += interval) {
      final x = xForAge(age);
      final tp = TextPainter(
        text: TextSpan(
          text: '$age',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartBottom + 6));

      // Small tick mark
      canvas.drawLine(
        Offset(x, chartBottom),
        Offset(x, chartBottom + 3),
        Paint()
          ..color = MintColors.lightBorder
          ..strokeWidth = 0.5,
      );
    }

    // "ans" label under the axis (centered)
    final ansTp = TextPainter(
      text: TextSpan(
        text: 'ans',
        style: GoogleFonts.inter(
          fontSize: 9,
          color: MintColors.textMuted,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ansTp.paint(
      canvas,
      Offset(size.width - _rightPadding - ansTp.width, chartBottom + 6),
    );
  }

  // ── Percentile labels on right edge of chart ────────────────

  void _drawPercentileLabels(
    Canvas canvas,
    double chartRight,
    double Function(double) yForValue,
  ) {
    if (points.isEmpty) return;

    final last = points.last;
    final labels = [
      ('P90', last.p90),
      ('P75', last.p75),
      ('P50', last.p50),
      ('P25', last.p25),
      ('P10', last.p10),
    ];

    // Track positions to avoid overlapping labels
    final usedYRanges = <(double, double)>[];

    for (final (label, value) in labels) {
      final y = yForValue(value);
      final isBold = label == 'P50';

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold
                ? MintColors.primary
                : MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelY = y - tp.height / 2;
      final labelBottom = labelY + tp.height;

      // Check for overlap with already placed labels
      bool overlaps = false;
      for (final (usedTop, usedBottom) in usedYRanges) {
        if (labelY < usedBottom + 2 && labelBottom > usedTop - 2) {
          overlaps = true;
          break;
        }
      }

      if (!overlaps) {
        tp.paint(canvas, Offset(chartRight + 2, labelY));
        usedYRanges.add((labelY, labelBottom));
      }
    }
  }

  // ── Number formatting helpers ───────────────────────────────

  /// Compact CHF formatting for axis labels.
  static String _formatAxisChf(double amount) {
    final rounded = amount.round().abs();
    final formatted = rounded.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => "${m[1]}'",
    );
    return "CHF\u00A0$formatted";
  }

  /// Determine a "nice" step value for grid lines.
  static double _niceStep(double rawStep) {
    if (rawStep <= 0) return 1000;
    final magnitude = pow(10, (log(rawStep) / ln10).floor()).toDouble();
    final normalized = rawStep / magnitude;

    if (normalized <= 1.5) return magnitude;
    if (normalized <= 3.5) return magnitude * 2;
    if (normalized <= 7.5) return magnitude * 5;
    return magnitude * 10;
  }

  @override
  bool shouldRepaint(covariant _MonteCarloFanPainter old) =>
      old.points != points ||
      old.currentMonthlyIncome != currentMonthlyIncome;
}

// ════════════════════════════════════════════════════════════════════
//  LEGEND LINE PAINTER (for solid/dashed legend swatches)
// ════════════════════════════════════════════════════════════════════

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool isDashed;

  _LegendLinePainter({required this.color, this.isDashed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;

    if (isDashed) {
      const dashLen = 4.0;
      const gapLen = 2.5;
      double x = 0;
      while (x < size.width) {
        final end = min(x + dashLen, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x = end + gapLen;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter old) =>
      old.color != color || old.isDashed != isDashed;
}
