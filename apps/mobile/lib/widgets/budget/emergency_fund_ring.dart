import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  EMERGENCY FUND RING — Sprint 2 UX
// ────────────────────────────────────────────────────────────
//
//  Mini ring gauge (120x120) showing emergency fund status:
//    - Full circle ring (360 degrees)
//    - Fill color: red <3 months, orange 3-5, green 6+
//    - SweepGradient fill + glow at endpoint + bright tip dot
//    - 6 tick marks (1 per target month)
//    - Center: months number + "mois" label
//    - 1200ms easeOutCubic animation
//
//  Widget pur — pas de Provider, uniquement des props.
// ────────────────────────────────────────────────────────────

class EmergencyFundRing extends StatefulWidget {
  /// Current months of expenses covered.
  final double months;

  /// Target months (default 6).
  final double target;

  /// Optional callback on tap.
  final VoidCallback? onTap;

  const EmergencyFundRing({
    super.key,
    required this.months,
    this.target = 6.0,
    this.onTap,
  });

  @override
  State<EmergencyFundRing> createState() => _EmergencyFundRingState();
}

class _EmergencyFundRingState extends State<EmergencyFundRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(EmergencyFundRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months != widget.months ||
        oldWidget.target != widget.target) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _ringColor {
    if (widget.months >= 6) return MintColors.success;
    if (widget.months >= 3) return MintColors.warning;
    return MintColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 120,
        height: 120,
        child: AnimatedBuilder(
          animation: _fillAnimation,
          builder: (context, _) {
            final displayMonths =
                (widget.months * _fillAnimation.value);

            return Stack(
              alignment: Alignment.center,
              children: [
                // Painted ring
                CustomPaint(
                  painter: _EmergencyRingPainter(
                    fraction: widget.target > 0
                        ? (widget.months / widget.target).clamp(0.0, 1.0)
                        : 0.0,
                    progress: _fillAnimation.value,
                    ringColor: _ringColor,
                    targetMonths: widget.target.round(),
                    currentMonths: widget.months,
                  ),
                  size: const Size(120, 120),
                ),
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayMonths.toStringAsFixed(1),
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _ringColor,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'mois',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  EMERGENCY RING CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _EmergencyRingPainter extends CustomPainter {
  final double fraction;
  final double progress;
  final Color ringColor;
  final int targetMonths;
  final double currentMonths;

  _EmergencyRingPainter({
    required this.fraction,
    required this.progress,
    required this.ringColor,
    required this.targetMonths,
    required this.currentMonths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;
    const startAngle = -pi / 2; // start at top

    // ── Background track (full circle) ──
    final trackPaint = Paint()
      ..color = MintColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // ── Tick marks (1 per target month) ──
    _drawTickMarks(canvas, center, radius, strokeWidth);

    // ── Fill arc (animated) ──
    final fillSweep = fraction * 2 * pi * progress;

    if (fillSweep > 0.001) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      // SweepGradient fill
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + fillSweep,
          colors: [
            ringColor.withValues(alpha: 0.6),
            ringColor.withValues(alpha: 0.9),
            ringColor,
          ],
          stops: const [0.0, 0.6, 1.0],
          transform: const GradientRotation(-pi / 2),
        ).createShader(arcRect);

      canvas.drawArc(arcRect, startAngle, fillSweep, false, fillPaint);

      // ── Glow at endpoint ──
      final endAngle = startAngle + fillSweep;
      final glowCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            ringColor.withValues(alpha: 0.35),
            ringColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowCenter, radius: 12),
        );
      canvas.drawCircle(glowCenter, 12, glowPaint);

      // Bright tip dot
      final tipPaint = Paint()..color = ringColor;
      canvas.drawCircle(glowCenter, 3.5, tipPaint);
    }
  }

  /// Draw 6 tick marks (1 per target month) around the ring.
  void _drawTickMarks(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
  ) {
    final tickInner = radius - strokeWidth / 2 - 2;
    final tickOuter = radius + strokeWidth / 2 + 2;
    final numTicks = targetMonths > 0 ? targetMonths : 6;

    for (var i = 0; i < numTicks; i++) {
      final frac = i / numTicks;
      final angle = -pi / 2 + frac * 2 * pi;

      final innerPoint = Offset(
        center.dx + tickInner * cos(angle),
        center.dy + tickInner * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + tickOuter * cos(angle),
        center.dy + tickOuter * sin(angle),
      );

      // Color: filled ticks use the ring color, unfilled use border
      final isFilled = i < (currentMonths * progress).floor();
      final tickPaint = Paint()
        ..color = isFilled
            ? ringColor.withValues(alpha: 0.6)
            : MintColors.border.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmergencyRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.currentMonths != currentMonths;
  }
}
