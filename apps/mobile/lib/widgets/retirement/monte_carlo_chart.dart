import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Graphique en eventail (fan/ribbon chart) — projection du revenu
/// de retraite sur 25-30 ans, en langage humain.
///
/// Affiche 3 bandes visuelles :
///   - Fourchette large (P10-P90) : MintColors.primary, alpha 0.08
///   - Fourchette probable (P25-P75) : MintColors.primary, alpha 0.18
///   - Scenario central (P50) : MintColors.primary, trait plein 2px
///
/// Au-dessus du graphique : nombre-hero (probabilite positive)
/// et phrase humaine explicative.
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

    final l = S.of(context)!;
    final successPct = ((1 - result.ruinProbability) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Titre --
        Text(
          l.monteCarloTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary)
              .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          l.monteCarloSubtitle(result.numSimulations),
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
              .copyWith(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),

        // -- Hero number (positive probability) --
        Center(
          child: Column(
            children: [
              Text(
                '$successPct\u00a0%',
                style: MintTextStyles.displayMedium(
                  color: _successColor(successPct),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.monteCarloHeroPhrase,
                textAlign: TextAlign.center,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ).copyWith(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // -- Chart --
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

        // -- Legende --
        _buildLegend(l),
        const SizedBox(height: 16),

        // -- Carte de synthese --
        _buildSummaryCard(l, successPct),
        const SizedBox(height: 12),

        // -- Disclaimer --
        Text(
          l.monteCarloDisclaimer,
          style: MintTextStyles.micro(color: MintColors.textMuted)
              .copyWith(fontSize: 10, fontStyle: FontStyle.normal, height: 1.4),
        ),
      ],
    );
  }

  /// Color for the hero probability number.
  Color _successColor(int pct) {
    if (pct >= 75) return MintColors.success;
    if (pct >= 50) return MintColors.warning;
    return MintColors.error;
  }

  // ================================================================
  //  LEGEND
  // ================================================================

  Widget _buildLegend(S l) {
    final items = <Widget>[
      _legendItem(
        l.monteCarloLegendWideBand,
        MintColors.primary.withValues(alpha: 0.08),
        border: MintColors.primary.withValues(alpha: 0.18),
      ),
      _legendItem(
        l.monteCarloLegendProbableBand,
        MintColors.primary.withValues(alpha: 0.18),
        border: MintColors.primary.withValues(alpha: 0.35),
      ),
      _legendItem(
        l.monteCarloLegendMedian,
        MintColors.primary,
        isLine: true,
      ),
    ];

    if (currentMonthlyIncome != null) {
      items.add(_legendItem(
        l.monteCarloLegendCurrentIncome,
        MintColors.amber,
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
              borderRadius: BorderRadius.circular(2),
              border: border != null
                  ? Border.all(color: border, width: 0.5)
                  : null,
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
        ),
      ],
    );
  }

  // ================================================================
  //  SUMMARY CARD
  // ================================================================

  Widget _buildSummaryCard(S l, int successPct) {
    // Color coding for success probability
    final Color successColor;
    if (successPct >= 75) {
      successColor = MintColors.success;
    } else if (successPct >= 50) {
      successColor = MintColors.warning;
    } else {
      successColor = MintColors.error;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MintColors.lightBorder, width: 1),
      ),
      color: MintColors.cardGround,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            // -- Scenario central a l'age de retraite --
            _summaryRow(
              l.monteCarloMedianAtAge(result.retirementAge),
              '${formatChfWithPrefix(result.medianAt65)}/mois',
            ),
            const SizedBox(height: 10),

            // -- Fourchette probable --
            _summaryRow(
              l.monteCarloProbableRange,
              '${formatChfWithPrefix(result.p10At65)} \u2014 ${formatChfWithPrefix(result.p90At65)}',
            ),
            const SizedBox(height: 10),

            // -- Probabilite positive --
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    l.monteCarloSuccessLabel,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary,
                    ).copyWith(fontSize: 12, height: 1.35),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$successPct\u00a0%',
                        style: MintTextStyles.bodyLarge(color: successColor)
                            .copyWith(
                                fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: _buildSuccessBar(successPct, successColor),
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
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)
                .copyWith(fontSize: 12, height: 1.35),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
      ],
    );
  }

  /// Mini horizontal bar for success probability visualization.
  Widget _buildSuccessBar(int pct, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            // Background track
            Container(
              decoration: BoxDecoration(
                color: MintColors.lightBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Filled portion
            FractionallySizedBox(
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  CUSTOM PAINTER — Fan/ribbon chart (3 bands)
// ================================================================

class _MonteCarloFanPainter extends CustomPainter {
  final List<MonteCarloPoint> points;
  final double? currentMonthlyIncome;

  _MonteCarloFanPainter({
    required this.points,
    this.currentMonthlyIncome,
  });

  // -- Layout constants --
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

    // -- Determine Y scale --
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

    // -- Determine X scale --
    final ageMin = points.firstOrNull?.age ?? 0;
    final ageMax = points.lastOrNull?.age ?? 0;
    final ageRange = ageMax - ageMin;
    if (ageRange <= 0) return;

    // -- Helper closures --
    double xForAge(int age) {
      return chartLeft + (age - ageMin) / ageRange * chartWidth;
    }

    double yForValue(double value) {
      return chartBottom - (value - yMin) / (yMax - yMin) * chartHeight;
    }

    // -- Grid lines --
    _drawGridLines(canvas, size, chartLeft, chartRight, chartTop, chartBottom,
        yMin, yMax, yForValue);

    // -- Fourchette large (P10-P90) --
    _drawBand(
      canvas: canvas,
      points: points,
      xForAge: xForAge,
      yForValue: yForValue,
      getLower: (p) => p.p10,
      getUpper: (p) => p.p90,
      color: MintColors.primary.withValues(alpha: 0.08),
    );

    // -- Fourchette probable (P25-P75) --
    _drawBand(
      canvas: canvas,
      points: points,
      xForAge: xForAge,
      yForValue: yForValue,
      getLower: (p) => p.p25,
      getUpper: (p) => p.p75,
      color: MintColors.primary.withValues(alpha: 0.18),
    );

    // -- Scenario central (P50 median line) --
    _drawPercentileLine(
      canvas: canvas,
      points: points,
      xForAge: xForAge,
      yForValue: yForValue,
      getValue: (p) => p.p50,
      color: MintColors.primary,
      strokeWidth: 2.0,
    );

    // -- Current income reference line --
    if (currentMonthlyIncome != null) {
      _drawReferenceLine(
        canvas: canvas,
        value: currentMonthlyIncome!,
        yForValue: yForValue,
        chartLeft: chartLeft,
        chartRight: chartRight,
      );
    }

    // -- X-axis labels --
    _drawXAxisLabels(canvas, size, chartBottom, ageMin, ageMax, xForAge);
  }

  // -- Grid lines with Y-axis labels --

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
      final label = formatChfWithPrefix(v);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: MintTextStyles.micro(color: MintColors.textMuted)
              .copyWith(fontSize: 10, fontStyle: FontStyle.normal),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - tp.height / 2));
    }
  }

  // -- Draw a shaded band between two percentile lines --

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

  // -- Draw a single percentile line --

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

  // -- Current income reference line (dashed, amber) --

  void _drawReferenceLine({
    required Canvas canvas,
    required double value,
    required double Function(double) yForValue,
    required double chartLeft,
    required double chartRight,
  }) {
    const color = MintColors.amber;
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
    final label = formatChfWithPrefix(value);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: MintTextStyles.micro(color: color).copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal),
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
    canvas.drawRRect(
        bgRect, Paint()..color = MintColors.white.withValues(alpha: 0.85));
    tp.paint(canvas, Offset(labelX, labelY));
  }

  // -- X-axis labels (ages) --

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
          style: MintTextStyles.micro(color: MintColors.textMuted)
              .copyWith(fontSize: 10, fontStyle: FontStyle.normal),
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
        style: MintTextStyles.micro(color: MintColors.textMuted)
            .copyWith(fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ansTp.paint(
      canvas,
      Offset(size.width - _rightPadding - ansTp.width, chartBottom + 6),
    );
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

// ================================================================
//  LEGEND LINE PAINTER (for solid/dashed legend swatches)
// ================================================================

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
