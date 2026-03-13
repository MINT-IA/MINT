import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  90-DAY RULE CIRCULAR GAUGE — Expatriation & Frontaliers
// ────────────────────────────────────────────────────────────
//
//  Dramatic circular gauge showing proximity to the 90-day
//  fiscal threshold for cross-border workers:
//    - 270° sweep arc with three color zones
//    - 0-70 days: green "Zone sure"
//    - 70-89 days: orange "Attention"
//    - 90+ days: red "Risque fiscal"
//    - Animated needle with pulse in red zone
//    - Center: large day count + "/ 90"
//    - Status text with recommendation below
// ────────────────────────────────────────────────────────────

class NinetyDayGauge extends StatefulWidget {
  /// Current number of days worked in Switzerland.
  final int currentDays;

  /// Maximum days on the gauge scale (default 120 to show overshoot).
  final int maxDays;

  /// Optional callback when tapped.
  final VoidCallback? onTap;

  const NinetyDayGauge({
    super.key,
    required this.currentDays,
    this.maxDays = 120,
    this.onTap,
  });

  @override
  State<NinetyDayGauge> createState() => _NinetyDayGaugeState();
}

class _NinetyDayGaugeState extends State<NinetyDayGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _needleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _needleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(NinetyDayGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDays != widget.currentDays) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isRedZone => widget.currentDays >= 90;
  bool get _isOrangeZone =>
      widget.currentDays >= 70 && widget.currentDays < 90;

  String get _statusText {
    if (_isRedZone) {
      return 'Seuil depasse — risque d\'imposition ordinaire en Suisse';
    } else if (_isOrangeZone) {
      final remaining = 90 - widget.currentDays;
      return 'Attention: plus que $remaining jour${remaining > 1 ? 's' : ''} avant le seuil';
    } else {
      final remaining = 90 - widget.currentDays;
      return 'Zone sure — $remaining jour${remaining > 1 ? 's' : ''} restants avant le seuil';
    }
  }

  Color get _statusColor {
    if (_isRedZone) return MintColors.error;
    if (_isOrangeZone) return MintColors.warning;
    return MintColors.success;
  }

  IconData get _statusIcon {
    if (_isRedZone) return Icons.warning_rounded;
    if (_isOrangeZone) return Icons.schedule;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Jauge de la regle des 90 jours. ${widget.currentDays} jours sur 90. ${_statusText}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MintColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: MintColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  // Gauge
                  AnimatedBuilder(
                    animation: _needleAnimation,
                    builder: (context, _) {
                      final gaugeSize = min(cardWidth - 48, 280.0);
                      return SizedBox(
                        width: gaugeSize,
                        height: gaugeSize * 0.72,
                        child: CustomPaint(
                          painter: _NinetyDayGaugePainter(
                            currentDays: widget.currentDays,
                            maxDays: widget.maxDays,
                            progress: _needleAnimation.value,
                            isRedZone: _isRedZone,
                          ),
                          child: _buildCenterLabel(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStatusBadge(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.timer_outlined,
            color: _statusColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Regle des 90 jours',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                'Frontaliers  ·  Seuil fiscal',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCenterLabel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _needleAnimation,
              builder: (context, _) {
                final displayDays =
                    (widget.currentDays * _needleAnimation.value).round();
                return Text(
                  '$displayDays',
                  style: GoogleFonts.montserrat(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: _statusColor,
                    height: 1.0,
                  ),
                );
              },
            ),
            Text(
              '/ 90 jours',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MintColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, size: 18, color: _statusColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _statusText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _statusColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  GAUGE CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _NinetyDayGaugePainter extends CustomPainter {
  final int currentDays;
  final int maxDays;
  final double progress;
  final bool isRedZone;

  _NinetyDayGaugePainter({
    required this.currentDays,
    required this.maxDays,
    required this.progress,
    required this.isRedZone,
  });

  static const double _startAngle = 135 * pi / 180; // 135°
  static const double _sweepAngle = 270 * pi / 180; // 270° total arc

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = min(size.width, size.height * 1.3) * 0.42;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // ── Background arc (track) ──
    final trackPaint = Paint()
      ..color = MintColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, trackPaint);

    // ── Zone arcs ──
    _drawZoneArcs(canvas, arcRect, radius, center);

    // ── Tick marks for key thresholds ──
    _drawTickMarks(canvas, center, radius);

    // ── Needle ──
    _drawNeedle(canvas, center, radius);

    // ── Needle pivot dot ──
    final pivotPaint = Paint()..color = MintColors.textPrimary;
    canvas.drawCircle(center, 6, pivotPaint);
    final pivotInner = Paint()..color = MintColors.white;
    canvas.drawCircle(center, 3, pivotInner);
  }

  void _drawZoneArcs(
      Canvas canvas, Rect arcRect, double radius, Offset center) {
    const trackWidth = 18.0;

    // Green zone: 0–70 days
    final greenSweep = (70 / maxDays) * _sweepAngle;
    final greenPaint = Paint()
      ..color = MintColors.success.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, _startAngle, greenSweep, false, greenPaint);

    // Orange zone: 70–89 days
    final orangeStart = _startAngle + greenSweep;
    final orangeSweep = (19 / maxDays) * _sweepAngle;
    final orangePaint = Paint()
      ..color = MintColors.warning.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(arcRect, orangeStart, orangeSweep, false, orangePaint);

    // Red zone: 90+ days
    final redStart = _startAngle + greenSweep + orangeSweep;
    final redSweep = _sweepAngle - greenSweep - orangeSweep;
    final redPaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, redStart, redSweep, false, redPaint);

    // ── Zone labels ──
    _drawZoneLabel(canvas, center, radius, 35 / maxDays, 'Zone sure',
        MintColors.success);
    _drawZoneLabel(canvas, center, radius, 79.5 / maxDays, 'Attention',
        MintColors.warning);
    _drawZoneLabel(canvas, center, radius, 105 / maxDays, 'Risque fiscal',
        MintColors.error);
  }

  void _drawZoneLabel(Canvas canvas, Offset center, double radius,
      double dayFraction, String text, Color color) {
    final angle = _startAngle + dayFraction * _sweepAngle;
    final labelRadius = radius + 26;
    final labelCenter = Offset(
      center.dx + labelRadius * cos(angle),
      center.dy + labelRadius * sin(angle),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2),
    );
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = MintColors.border
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Key thresholds: 0, 70, 90, maxDays
    for (final days in [0, 70, 90, maxDays]) {
      final fraction = days / maxDays;
      final angle = _startAngle + fraction * _sweepAngle;
      final innerR = radius - 14;
      final outerR = radius + 14;
      canvas.drawLine(
        Offset(center.dx + innerR * cos(angle),
            center.dy + innerR * sin(angle)),
        Offset(center.dx + outerR * cos(angle),
            center.dy + outerR * sin(angle)),
        tickPaint,
      );

      // Day number label
      final labelR = radius - 24;
      final labelCenter = Offset(
        center.dx + labelR * cos(angle),
        center.dy + labelR * sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$days',
          style: GoogleFonts.montserrat(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(labelCenter.dx - tp.width / 2,
            labelCenter.dy - tp.height / 2),
      );
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final dayFraction =
        (currentDays / maxDays).clamp(0.0, 1.0) * progress;
    final needleAngle = _startAngle + dayFraction * _sweepAngle;
    final needleLength = radius - 6;

    final needleTip = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    // Needle shadow / glow for red zone
    if (isRedZone && progress > 0.8) {
      final glowPaint = Paint()
        ..color = MintColors.error.withValues(alpha: 0.3 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(center, needleTip, glowPaint..strokeWidth = 6);
    }

    // Needle body
    final needlePaint = Paint()
      ..color = MintColors.textPrimary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    // Needle tip dot
    final tipDotPaint = Paint()
      ..color = isRedZone
          ? MintColors.error
          : currentDays >= 70
              ? MintColors.warning
              : MintColors.success;
    canvas.drawCircle(needleTip, 5, tipDotPaint);

    // Pulse ring on tip when in red zone
    if (isRedZone) {
      final pulseAlpha = (sin(progress * pi * 4) * 0.3 + 0.2).clamp(0.0, 1.0);
      final pulsePaint = Paint()
        ..color = MintColors.error.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(needleTip, 10, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NinetyDayGaugePainter oldDelegate) {
    return oldDelegate.currentDays != currentDays ||
        oldDelegate.maxDays != maxDays ||
        oldDelegate.progress != progress ||
        oldDelegate.isRedZone != isRedZone;
  }
}
