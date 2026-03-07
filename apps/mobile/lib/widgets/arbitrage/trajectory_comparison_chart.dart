import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';

/// CustomPainter-based chart that displays 2-4 trajectory lines on the same
/// axes, with a crossover indicator, legend, and tap-to-inspect popup.
///
/// Sprint S32 — Arbitrage Phase 1.
class TrajectoryComparisonChart extends StatefulWidget {
  final List<TrajectoireOption> options;
  final int? breakevenYear;
  final String selectedAxisLabel;

  /// Color palette for each option (indexed by order).
  final List<Color> colors;

  const TrajectoryComparisonChart({
    super.key,
    required this.options,
    this.breakevenYear,
    this.colors = const [],
    this.selectedAxisLabel = 'Annee',
  });

  @override
  State<TrajectoryComparisonChart> createState() =>
      _TrajectoryComparisonChartState();
}

class _TrajectoryComparisonChartState extends State<TrajectoryComparisonChart> {
  int? _selectedYearIndex;

  static const List<Color> _defaultColors = [
    MintColors.retirementAvs, // info blue
    MintColors.retirementLpp, // success green
    MintColors.trajectoryPrudent, // warning orange
    MintColors.purple, // purple
  ];

  List<Color> get _colors =>
      widget.colors.isNotEmpty ? widget.colors : _defaultColors;

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart area
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            const chartHeight = 250.0;

            return GestureDetector(
              onTapDown: (details) => _onTap(details, chartWidth, chartHeight),
              onPanUpdate: (details) =>
                  _onDrag(details, chartWidth, chartHeight),
              child: SizedBox(
                width: chartWidth,
                height: chartHeight,
                child: CustomPaint(
                  painter: _TrajectoryPainter(
                    options: widget.options,
                    colors: _colors,
                    breakevenYear: widget.breakevenYear,
                    selectedYearIndex: _selectedYearIndex,
                  ),
                  size: Size(chartWidth, chartHeight),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Selected year popup
        if (_selectedYearIndex != null) _buildSelectedPopup(),

        const SizedBox(height: 12),

        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (int i = 0; i < widget.options.length; i++)
              _LegendItem(
                color: i < _colors.length
                    ? _colors[i]
                    : _defaultColors[i % _defaultColors.length],
                label: widget.options[i].label,
              ),
          ],
        ),
      ],
    );
  }

  void _onTap(TapDownDetails details, double chartWidth, double chartHeight) {
    _resolveSelection(details.localPosition.dx, chartWidth);
  }

  void _onDrag(
      DragUpdateDetails details, double chartWidth, double chartHeight) {
    _resolveSelection(details.localPosition.dx, chartWidth);
  }

  void _resolveSelection(double dx, double chartWidth) {
    if (widget.options.isEmpty) return;
    final maxLen = widget.options.first.trajectory.length;
    if (maxLen <= 1) return;

    const leftPad = 60.0;
    const rightPad = 16.0;
    final usable = chartWidth - leftPad - rightPad;
    final fraction = ((dx - leftPad) / usable).clamp(0.0, 1.0);
    final index = (fraction * (maxLen - 1)).round().clamp(0, maxLen - 1);

    setState(() => _selectedYearIndex = index);
  }

  Widget _buildSelectedPopup() {
    final idx = _selectedYearIndex!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.selectedAxisLabel} ${widget.options.first.trajectory[idx].year}',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < widget.options.length; i++)
            if (idx < widget.options[i].trajectory.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i < _colors.length
                            ? _colors[i]
                            : _defaultColors[i % _defaultColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.options[i].label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      _formatChf(
                          widget.options[i].trajectory[idx].netPatrimony),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _formatChf(double value) {
    final intVal = value.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${value < 0 ? '-' : ''}${buffer.toString()}';
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LEGEND ITEM
// ═══════════════════════════════════════════════════════════════════

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CUSTOM PAINTER
// ═══════════════════════════════════════════════════════════════════

class _TrajectoryPainter extends CustomPainter {
  final List<TrajectoireOption> options;
  final List<Color> colors;
  final int? breakevenYear;
  final int? selectedYearIndex;

  static const double _leftPad = 60;
  static const double _rightPad = 16;
  static const double _topPad = 16;
  static const double _bottomPad = 32;

  _TrajectoryPainter({
    required this.options,
    required this.colors,
    this.breakevenYear,
    this.selectedYearIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (options.isEmpty) return;

    const chartLeft = _leftPad;
    final chartRight = size.width - _rightPad;
    const chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    // Compute global min/max across all trajectories
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;
    int maxLen = 0;

    for (final option in options) {
      for (final snap in option.trajectory) {
        if (snap.netPatrimony < globalMin) globalMin = snap.netPatrimony;
        if (snap.netPatrimony > globalMax) globalMax = snap.netPatrimony;
      }
      if (option.trajectory.length > maxLen) {
        maxLen = option.trajectory.length;
      }
    }

    if (maxLen <= 1 || globalMax == globalMin) return;

    // Add 10% padding to Y range
    final yRange = globalMax - globalMin;
    final yMin = globalMin - yRange * 0.05;
    final yMax = globalMax + yRange * 0.05;

    // Draw grid lines and Y-axis labels
    _drawGrid(
        canvas, size, chartLeft, chartRight, chartTop, chartBottom, yMin, yMax);

    // Draw X-axis labels (every 5 years)
    _drawXLabels(canvas, chartLeft, chartWidth, chartBottom, maxLen);

    // Draw trajectory lines
    for (int i = 0; i < options.length; i++) {
      final color = i < colors.length ? colors[i] : Colors.grey;
      _drawLine(canvas, options[i].trajectory, color, chartLeft, chartWidth,
          chartTop, chartHeight, maxLen, yMin, yMax);
    }

    // Draw breakeven vertical line
    if (breakevenYear != null && breakevenYear! < maxLen) {
      _drawBreakevenLine(canvas, breakevenYear!, chartLeft, chartWidth,
          chartTop, chartBottom, maxLen);
    }

    // Draw selection vertical line
    if (selectedYearIndex != null && selectedYearIndex! < maxLen) {
      _drawSelectionLine(canvas, selectedYearIndex!, chartLeft, chartWidth,
          chartTop, chartBottom, maxLen, yMin, yMax);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double left, double right,
      double top, double bottom, double yMin, double yMax) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E5E7)
      ..strokeWidth = 0.5;

    const gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      final y = top + (bottom - top) * i / gridLines;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);

      // Y-axis label
      final value = yMax - (yMax - yMin) * i / gridLines;
      final label = _formatAxisValue(value);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF86868B),
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _leftPad - 8);
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }
  }

  void _drawXLabels(Canvas canvas, double chartLeft, double chartWidth,
      double chartBottom, int maxLen) {
    if (maxLen <= 1) return;
    final firstYear = options.first.trajectory.first.year;

    for (int i = 0; i < maxLen; i += 5) {
      final x = chartLeft + chartWidth * i / (maxLen - 1);
      final year = firstYear + i;
      final tp = TextPainter(
        text: TextSpan(
          text: '$year',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF86868B),
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartBottom + 6));
    }
  }

  void _drawLine(
    Canvas canvas,
    List<YearlySnapshot> trajectory,
    Color color,
    double chartLeft,
    double chartWidth,
    double chartTop,
    double chartHeight,
    int maxLen,
    double yMin,
    double yMax,
  ) {
    if (trajectory.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < trajectory.length; i++) {
      final x = chartLeft + chartWidth * i / (maxLen - 1);
      final yFraction = (trajectory[i].netPatrimony - yMin) / (yMax - yMin);
      final y = chartTop + chartHeight * (1 - yFraction);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawBreakevenLine(Canvas canvas, int yearIndex, double chartLeft,
      double chartWidth, double chartTop, double chartBottom, int maxLen) {
    final x = chartLeft + chartWidth * yearIndex / (maxLen - 1);
    final paint = Paint()
      ..color = MintColors.textMuted.withAlpha(120)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Dashed line
    const dashLen = 6.0;
    const gapLen = 4.0;
    double y = chartTop;
    while (y < chartBottom) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + dashLen, chartBottom)),
        paint,
      );
      y += dashLen + gapLen;
    }

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: 'Croisement',
        style: TextStyle(
          fontSize: 9,
          color: MintColors.textMuted.withAlpha(180),
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, chartTop - 14));
  }

  void _drawSelectionLine(Canvas canvas, int yearIndex, double chartLeft,
      double chartWidth, double chartTop, double chartBottom, int maxLen,
      double yMin, double yMax) {
    final x = chartLeft + chartWidth * yearIndex / (maxLen - 1);
    final paint = Paint()
      ..color = MintColors.primary.withAlpha(80)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, chartTop), Offset(x, chartBottom), paint);

    if (yMax == yMin) return;
    final chartHeight = chartBottom - chartTop;

    // Draw dots on each trajectory
    for (int i = 0; i < options.length; i++) {
      if (yearIndex < options[i].trajectory.length) {
        final val = options[i].trajectory[yearIndex].netPatrimony;
        final yFraction = (val - yMin) / (yMax - yMin);
        final y = chartTop + chartHeight * (1 - yFraction);
        final color = i < colors.length ? colors[i] : Colors.grey;
        canvas.drawCircle(
          Offset(x, y),
          5,
          Paint()..color = color,
        );
        canvas.drawCircle(
          Offset(x, y),
          3,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  String _formatAxisValue(double value) {
    final absVal = value.abs();
    if (absVal >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (absVal >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) {
    return oldDelegate.options != options ||
        oldDelegate.breakevenYear != breakevenYear ||
        oldDelegate.selectedYearIndex != selectedYearIndex;
  }
}
