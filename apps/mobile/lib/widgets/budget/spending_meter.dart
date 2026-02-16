import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  SPENDING METER — Sprint 2 UX Rewrite
// ────────────────────────────────────────────────────────────
//
//  Animated CustomPainter donut chart showing budget allocation:
//    - Segment 1 "Variables": MintColors.success (green)
//    - Segment 2 "Future":    MintColors.info (blue)
//    - Background track:      MintColors.surface
//    - SweepGradient per segment + glow at endpoint + bright tip dot
//    - Center: "Disponible" label + animated CHF counter
//    - Legend row below donut with colored dots
//    - 1400ms easeOutCubic animation
//
//  Widget pur — pas de Provider, uniquement des props.
// ────────────────────────────────────────────────────────────

class SpendingMeter extends StatefulWidget {
  final double variablesAmount;
  final double futureAmount;
  final double totalAvailable;
  final String currency;

  const SpendingMeter({
    super.key,
    required this.variablesAmount,
    required this.futureAmount,
    required this.totalAvailable,
    this.currency = 'CHF',
  });

  @override
  State<SpendingMeter> createState() => _SpendingMeterState();
}

class _SpendingMeterState extends State<SpendingMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(SpendingMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variablesAmount != widget.variablesAmount ||
        oldWidget.futureAmount != widget.futureAmount ||
        oldWidget.totalAvailable != widget.totalAvailable) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _variablesFraction =>
      widget.totalAvailable > 0
          ? (widget.variablesAmount / widget.totalAvailable).clamp(0.0, 1.0)
          : 0.0;

  double get _futureFraction =>
      widget.totalAvailable > 0
          ? (widget.futureAmount / widget.totalAvailable).clamp(0.0, 1.0)
          : 0.0;

  int get _variablesPercent => (_variablesFraction * 100).round();
  int get _futurePercent => (_futureFraction * 100).round();

  /// Format a number with Swiss apostrophe thousands separator.
  String _formatAmount(double value) {
    final abs = value.abs().round();
    final str = abs.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return '${widget.currency} $buffer';
  }

  @override
  Widget build(BuildContext context) {
    // Edge case: no data
    if (widget.totalAvailable <= 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Budget non disponible',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Donut chart ──────────────────────────────────
        SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              final displayAmount =
                  (widget.totalAvailable * _fillAnimation.value);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Custom painted donut
                  CustomPaint(
                    painter: _SpendingDonutPainter(
                      variablesFraction: _variablesFraction,
                      futureFraction: _futureFraction,
                      progress: _fillAnimation.value,
                    ),
                    size: const Size(200, 200),
                  ),
                  // Center content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Disponible',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatAmount(displayAmount),
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Legend row ────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(
              color: MintColors.success,
              label: 'Variables $_variablesPercent%',
            ),
            const SizedBox(width: 24),
            _buildLegendItem(
              color: MintColors.info,
              label: 'Futur $_futurePercent%',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: MintColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  SPENDING DONUT CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _SpendingDonutPainter extends CustomPainter {
  final double variablesFraction;
  final double futureFraction;
  final double progress;

  /// Gap between segments in radians (~4 degrees).
  static const double _gapRad = 4 * pi / 180;

  _SpendingDonutPainter({
    required this.variablesFraction,
    required this.futureFraction,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;
    const strokeWidth = 22.0;
    const startAngle = -pi / 2; // top

    // ── Background track (full circle) ──
    final trackPaint = Paint()
      ..color = MintColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Compute segment sweeps
    final totalFraction = (variablesFraction + futureFraction).clamp(0.0, 1.0);
    final hasTwo = variablesFraction > 0 && futureFraction > 0;
    final gapCount = hasTwo ? 2 : 0; // gaps between two segments
    final totalGap = gapCount * _gapRad;
    final availableSweep = 2 * pi * totalFraction - totalGap;

    if (availableSweep <= 0) return;

    final variablesSweep = totalFraction > 0
        ? availableSweep * (variablesFraction / totalFraction)
        : 0.0;
    final futureSweep = totalFraction > 0
        ? availableSweep * (futureFraction / totalFraction)
        : 0.0;

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // ── Segment 1: Variables (green) ──
    if (variablesSweep > 0.001) {
      final sweep = variablesSweep * progress;
      _drawSegment(
        canvas: canvas,
        arcRect: arcRect,
        center: center,
        radius: radius,
        startAngle: startAngle,
        sweep: sweep,
        color: MintColors.success,
        strokeWidth: strokeWidth,
      );
    }

    // ── Segment 2: Future (blue) ──
    if (futureSweep > 0.001) {
      final seg2Start = startAngle +
          variablesSweep * progress +
          (hasTwo ? _gapRad : 0);
      final sweep = futureSweep * progress;
      _drawSegment(
        canvas: canvas,
        arcRect: arcRect,
        center: center,
        radius: radius,
        startAngle: seg2Start,
        sweep: sweep,
        color: MintColors.info,
        strokeWidth: strokeWidth,
      );
    }
  }

  void _drawSegment({
    required Canvas canvas,
    required Rect arcRect,
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweep,
    required Color color,
    required double strokeWidth,
  }) {
    if (sweep <= 0.001) return;

    // SweepGradient fill
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: [
          color.withValues(alpha: 0.5),
          color.withValues(alpha: 0.8),
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(arcRect);

    canvas.drawArc(arcRect, startAngle, sweep, false, fillPaint);

    // ── Glow at endpoint ──
    final endAngle = startAngle + sweep;
    final glowCenter = Offset(
      center.dx + radius * cos(endAngle),
      center.dy + radius * sin(endAngle),
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: glowCenter, radius: 14),
      );
    canvas.drawCircle(glowCenter, 14, glowPaint);

    // Bright tip dot
    final tipPaint = Paint()..color = color;
    canvas.drawCircle(glowCenter, 4.5, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _SpendingDonutPainter oldDelegate) {
    return oldDelegate.variablesFraction != variablesFraction ||
        oldDelegate.futureFraction != futureFraction ||
        oldDelegate.progress != progress;
  }
}
