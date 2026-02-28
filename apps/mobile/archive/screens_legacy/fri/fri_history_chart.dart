/// FRI History Chart — Sprint S39.
///
/// CustomPainter line chart showing FRI total over time.
/// X-axis: months. Y-axis: 0-100.
/// Color-coded background zones:
///   - <35: red (scoreCritique)
///   - 35-55: orange (scoreAttention)
///   - 55-75: light green (scoreBon)
///   - 75+: green (scoreExcellent)
///
/// Features:
///   - Smooth cubic bezier curve between data points
///   - Filled gradient area under the curve
///   - Date labels on X axis (MMM format: Jan, Fev, Mar...)
///   - Score labels on Y axis (0, 25, 50, 75, 100)
///   - Minimum 2 data points required; otherwise shows placeholder text
///
/// Design: CustomPainter, Montserrat headings, Inter body, MintColors.
/// All text in French (informal "tu"). No banned terms.
///
/// References:
///   - ONBOARDING_ARBITRAGE_ENGINE.md § V
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// A single data point for the FRI history chart.
class FriHistoryPoint {
  /// Date of this FRI snapshot.
  final DateTime date;

  /// Total FRI score at this date (0-100).
  final double total;

  const FriHistoryPoint({required this.date, required this.total});
}

/// Longitudinal FRI chart showing 6-12 months of progression.
///
/// Shows a smooth line chart with color-coded background zones.
/// If [history] contains fewer than 2 points, displays a placeholder
/// message encouraging the user to continue check-ins.
class FriHistoryChart extends StatelessWidget {
  /// Historical FRI data points (should be sorted chronologically).
  final List<FriHistoryPoint> history;

  /// Optional title override. Defaults to "Ta progression".
  final String? title;

  const FriHistoryChart({
    super.key,
    required this.history,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title ?? 'Ta progression',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),

          // Chart or placeholder
          if (history.length < 2)
            _buildPlaceholder()
          else
            _buildChart(),
        ],
      ),
    );
  }

  /// Placeholder when fewer than 2 data points.
  Widget _buildPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timeline_rounded,
                color: MintColors.textMuted.withAlpha(120),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                'Continue tes check-ins pour voir ta progression.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The actual chart with CustomPainter.
  Widget _buildChart() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        painter: _FriChartPainter(history: history),
        size: Size.infinite,
      ),
    );
  }
}

/// French month abbreviations.
const _frenchMonths = [
  'Jan',
  'Fev',
  'Mar',
  'Avr',
  'Mai',
  'Juin',
  'Juil',
  'Aout',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// CustomPainter for the FRI history line chart.
///
/// Draws:
///   1. Color-coded background zones (horizontal bands)
///   2. Grid lines + Y-axis labels
///   3. Smooth cubic bezier curve through data points
///   4. Gradient fill under the curve
///   5. Data point dots
///   6. X-axis month labels
class _FriChartPainter extends CustomPainter {
  final List<FriHistoryPoint> history;

  _FriChartPainter({required this.history});

  // Layout constants
  static const double _leftPadding = 32.0;
  static const double _rightPadding = 12.0;
  static const double _topPadding = 8.0;
  static const double _bottomPadding = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final chartLeft = _leftPadding;
    final chartRight = size.width - _rightPadding;
    final chartTop = _topPadding;
    final chartBottom = size.height - _bottomPadding;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    // 1. Background color zones
    _drawZones(canvas, chartLeft, chartTop, chartRight, chartBottom, chartHeight);

    // 2. Grid lines + Y-axis labels
    _drawGrid(canvas, size, chartLeft, chartTop, chartRight, chartBottom, chartHeight);

    // 3. Build data points in chart coordinates
    final points = _buildPoints(chartLeft, chartTop, chartWidth, chartHeight);

    // 4. Build smooth path
    final path = _buildSmoothPath(points);

    // 5. Gradient fill under curve
    _drawFill(canvas, path, points, chartLeft, chartRight, chartBottom);

    // 6. Line
    _drawLine(canvas, path);

    // 7. Data point dots
    _drawDots(canvas, points);

    // 8. X-axis labels
    _drawXLabels(canvas, points, chartBottom);
  }

  /// Draws color-coded horizontal zone bands.
  void _drawZones(Canvas canvas, double left, double top, double right,
      double bottom, double chartHeight) {
    final zones = [
      (0.0, 35.0, MintColors.scoreCritique),
      (35.0, 55.0, MintColors.scoreAttention),
      (55.0, 75.0, MintColors.scoreBon),
      (75.0, 100.0, MintColors.scoreExcellent),
    ];

    for (final (lo, hi, color) in zones) {
      final yBottom = bottom - (lo / 100.0) * chartHeight;
      final yTop = bottom - (hi / 100.0) * chartHeight;
      canvas.drawRect(
        Rect.fromLTRB(left, yTop, right, yBottom),
        Paint()..color = color.withAlpha(12),
      );
    }
  }

  /// Draws horizontal grid lines and Y-axis score labels.
  void _drawGrid(Canvas canvas, Size size, double left, double top,
      double right, double bottom, double chartHeight) {
    final gridPaint = Paint()
      ..color = MintColors.lightBorder
      ..strokeWidth = 0.5;

    const yValues = [0, 25, 50, 75, 100];

    for (final yVal in yValues) {
      final y = bottom - (yVal / 100.0) * chartHeight;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);

      // Y-axis label
      final tp = TextPainter(
        text: TextSpan(
          text: '$yVal',
          style: const TextStyle(
            fontSize: 10,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }
  }

  /// Converts data points to chart coordinates.
  List<Offset> _buildPoints(
      double chartLeft, double chartTop, double chartWidth, double chartHeight) {
    final sorted = List<FriHistoryPoint>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final minTime = sorted.first.date.millisecondsSinceEpoch.toDouble();
    final maxTime = sorted.last.date.millisecondsSinceEpoch.toDouble();
    final timeSpan = maxTime - minTime;

    final points = <Offset>[];
    for (final point in sorted) {
      final xFraction = timeSpan > 0
          ? (point.date.millisecondsSinceEpoch - minTime) / timeSpan
          : 0.5;
      final x = chartLeft + xFraction * chartWidth;
      final y =
          chartTop + chartHeight - (point.total.clamp(0, 100) / 100.0) * chartHeight;
      points.add(Offset(x, y));
    }
    return points;
  }

  /// Builds a smooth cubic bezier path through the data points.
  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      // Control points with 1/3 tension
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    return path;
  }

  /// Draws gradient fill under the curve.
  void _drawFill(Canvas canvas, Path linePath, List<Offset> points,
      double chartLeft, double chartRight, double chartBottom) {
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartBottom)
      ..lineTo(points.first.dx, chartBottom)
      ..close();

    final minY = points.map((p) => p.dy).reduce(math.min);

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, minY),
        Offset(0, chartBottom),
        [
          MintColors.info.withAlpha(50),
          MintColors.info.withAlpha(5),
        ],
      );

    canvas.drawPath(fillPath, fillPaint);
  }

  /// Draws the main line.
  void _drawLine(Canvas canvas, Path path) {
    final linePaint = Paint()
      ..color = MintColors.info
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  /// Draws dots at each data point.
  void _drawDots(Canvas canvas, List<Offset> points) {
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = MintColors.info
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final p in points) {
      canvas.drawCircle(p, 4, dotFill);
      canvas.drawCircle(p, 4, dotStroke);
    }
  }

  /// Draws month labels on the X axis.
  void _drawXLabels(Canvas canvas, List<Offset> points, double chartBottom) {
    final sorted = List<FriHistoryPoint>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Show at most 6 labels to avoid overlap
    final step = (sorted.length / 6).ceil().clamp(1, sorted.length);

    for (var i = 0; i < sorted.length; i += step) {
      final monthIdx = sorted[i].date.month - 1;
      final label = _frenchMonths[monthIdx];

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 10,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = points[i].dx - tp.width / 2;
      tp.paint(canvas, Offset(x, chartBottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _FriChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
