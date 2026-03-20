import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  PENSION COMPLETENESS RING — Expatriation & Frontaliers
// ────────────────────────────────────────────────────────────
//
//  Animated concentric ring chart showing AVS pension completeness:
//    - Outer ring: total contribution years needed (44 = 100%)
//    - Inner arc: years actually contributed in CH
//    - Gap section: dashed red arc for missing years
//    - Center: large percentage + "completude" text
//    - Year markers around ring (like a clock)
//    - Animated fill from 0 to current
//    - "Annees manquantes: X" + impact text below
//    - Voluntary contribution callout badge
// ────────────────────────────────────────────────────────────

/// Format a number with Swiss apostrophe thousands separator.
String _formatChf(double value) {
  final isNeg = value < 0;
  final abs = value.abs().round();
  final str = abs.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}CHF $buffer';
}

class PensionCompletenessRing extends StatefulWidget {
  /// Number of years the person has actually contributed to AVS in CH.
  final int contributedYears;

  /// Total years required for a full AVS pension (usually 44).
  final int totalYearsRequired;

  /// Estimated monthly pension reduction per missing year (CHF).
  final double reductionPerMissingYear;

  /// Estimated full monthly pension (CHF).
  final double fullMonthlyPension;

  /// Optional callback on tap.
  final VoidCallback? onTap;

  const PensionCompletenessRing({
    super.key,
    required this.contributedYears,
    this.totalYearsRequired = 44,
    this.reductionPerMissingYear = 55.0,
    this.fullMonthlyPension = 2520.0,
    this.onTap,
  });

  @override
  State<PensionCompletenessRing> createState() =>
      _PensionCompletenessRingState();
}

class _PensionCompletenessRingState extends State<PensionCompletenessRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(PensionCompletenessRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contributedYears != widget.contributedYears ||
        oldWidget.totalYearsRequired != widget.totalYearsRequired) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _missingYears =>
      (widget.totalYearsRequired - widget.contributedYears)
          .clamp(0, widget.totalYearsRequired);

  double get _completeness =>
      widget.totalYearsRequired > 0
          ? (widget.contributedYears / widget.totalYearsRequired)
              .clamp(0.0, 1.0)
          : 0.0;

  double get _estimatedPension =>
      widget.fullMonthlyPension -
      (_missingYears * widget.reductionPerMissingYear);

  Color get _ringColor {
    if (_completeness >= 0.9) return MintColors.success;
    if (_completeness >= 0.6) return MintColors.warning;
    return MintColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Complétude de la pension AVS. ${widget.contributedYears} années sur ${widget.totalYearsRequired}. '
          '${(_completeness * 100).round()} pour cent complete.',
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
                  _buildRing(cardWidth),
                  const SizedBox(height: 20),
                  _buildMissingYearsInfo(),
                  if (_missingYears > 0) ...[
                    const SizedBox(height: 12),
                    _buildVoluntaryContributionBadge(),
                  ],
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
            color: _ringColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.donut_large,
            color: _ringColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complétude AVS',
                style: MintTextStyles.titleMedium(),
              ),
              Text(
                'Années de cotisation  ·  Rente mensuelle',
                style: MintTextStyles.bodyMedium().copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRing(double cardWidth) {
    final ringSize = min(cardWidth - 48, 240.0);

    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, _) {
        final displayPct =
            (_completeness * 100 * _fillAnimation.value).round();

        return SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _PensionRingPainter(
                  completeness: _completeness,
                  totalYears: widget.totalYearsRequired,
                  contributedYears: widget.contributedYears,
                  progress: _fillAnimation.value,
                  ringColor: _ringColor,
                ),
                size: Size(ringSize, ringSize),
              ),
              // Center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$displayPct%',
                    style: MintTextStyles.displayMedium(color: _ringColor).copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'complétude',
                    style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(widget.contributedYears * _fillAnimation.value).round()} / ${widget.totalYearsRequired} ans',
                    style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMissingYearsInfo() {
    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, _) {
        final show = _fillAnimation.value > 0.6;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        label: 'Années manquantes',
                        value: '$_missingYears',
                        color: _missingYears > 0
                            ? MintColors.error
                            : MintColors.success,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: MintColors.lightBorder,
                    ),
                    Expanded(
                      child: _buildInfoTile(
                        label: 'Rente estimée',
                        value: _formatChf(_estimatedPension),
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (_missingYears > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trending_down,
                          size: 16,
                          color: MintColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Réduction estimée: ${_formatChf(_missingYears * widget.reductionPerMissingYear)}/mois',
                            style: MintTextStyles.bodyMedium(color: MintColors.error).copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: MintTextStyles.labelSmall(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: MintTextStyles.headlineMedium(color: color).copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVoluntaryContributionBadge() {
    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, _) {
        final show = _fillAnimation.value > 0.8;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedScale(
            scale: show ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MintColors.info.withValues(alpha: 0.08),
                    MintColors.info.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MintColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: MintColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: MintColors.info,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cotisations volontaires AVS',
                          style: MintTextStyles.bodyMedium(color: MintColors.info).copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tu peux combler des lacunes en cotisant volontairement dans les 5 ans suivant ton départ.',
                          style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
//  PENSION RING CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _PensionRingPainter extends CustomPainter {
  final double completeness;
  final int totalYears;
  final int contributedYears;
  final double progress;
  final Color ringColor;

  _PensionRingPainter({
    required this.completeness,
    required this.totalYears,
    required this.contributedYears,
    required this.progress,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = min(size.width, size.height) / 2 - 8;
    final innerRadius = outerRadius - 22;

    // ── Outer track ring ──
    final trackPaint = Paint()
      ..color = MintColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, (outerRadius + innerRadius) / 2, trackPaint);

    // ── Filled arc (contributed years) ──
    final fillSweep = completeness * 2 * pi * progress;
    const startAngle = -pi / 2; // start at top

    if (fillSweep > 0) {
      final fillRect = Rect.fromCircle(
          center: center, radius: (outerRadius + innerRadius) / 2);

      // Gradient fill
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
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
        ).createShader(fillRect);

      canvas.drawArc(fillRect, startAngle, fillSweep, false, fillPaint);

      // Glow at arc endpoint
      final endAngle = startAngle + fillSweep;
      final glowCenter = Offset(
        center.dx +
            (outerRadius + innerRadius) / 2 * cos(endAngle),
        center.dy +
            (outerRadius + innerRadius) / 2 * sin(endAngle),
      );
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            ringColor.withValues(alpha: 0.4),
            ringColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowCenter, radius: 16),
        );
      canvas.drawCircle(glowCenter, 16, glowPaint);

      // Bright dot at tip
      final tipPaint = Paint()..color = ringColor;
      canvas.drawCircle(glowCenter, 5, tipPaint);
    }

    // ── Dashed gap arc (missing years) ──
    if (completeness < 1.0 && progress > 0.3) {
      final gapStart = startAngle + fillSweep;
      final gapSweep = (1.0 - completeness) * 2 * pi;
      final gapRadius = (outerRadius + innerRadius) / 2;
      final dashPaint = Paint()
        ..color = MintColors.error.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Draw dashed arc
      const dashLength = 8.0;
      const dashGap = 6.0;
      final circumference = gapRadius * gapSweep.abs();
      final dashes = (circumference / (dashLength + dashGap)).floor();

      for (var d = 0; d < dashes; d++) {
        final fraction = d / dashes;
        final dashStart = gapStart + fraction * gapSweep;
        final dashSweepAngle =
            (dashLength / circumference) * gapSweep;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: gapRadius),
          dashStart,
          dashSweepAngle,
          false,
          dashPaint,
        );
      }
    }

    // ── Year tick marks around the ring ──
    _drawYearMarkers(canvas, center, outerRadius);
  }

  void _drawYearMarkers(Canvas canvas, Offset center, double outerRadius) {
    final markerRadius = outerRadius + 4;
    final totalMarkers = totalYears;

    for (var y = 0; y <= totalMarkers; y++) {
      final fraction = y / totalMarkers;
      final angle = -pi / 2 + fraction * 2 * pi;
      final isMajor = y % 10 == 0 || y == totalMarkers;
      final tickLen = isMajor ? 8.0 : 4.0;

      final tickPaint = Paint()
        ..color = y <= (contributedYears * progress).round()
            ? ringColor.withValues(alpha: 0.6)
            : MintColors.border.withValues(alpha: 0.4)
        ..strokeWidth = isMajor ? 2.0 : 1.0
        ..strokeCap = StrokeCap.round;

      final innerPoint = Offset(
        center.dx + markerRadius * cos(angle),
        center.dy + markerRadius * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + (markerRadius + tickLen) * cos(angle),
        center.dy + (markerRadius + tickLen) * sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Major marker labels (0, 10, 20, 30, 40, 44)
      if (isMajor) {
        final labelTp = TextPainter(
          text: TextSpan(
            text: '$y',
            style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelTp.layout();
        final labelCenter = Offset(
          center.dx + (markerRadius + tickLen + 10) * cos(angle),
          center.dy + (markerRadius + tickLen + 10) * sin(angle),
        );
        labelTp.paint(
          canvas,
          Offset(labelCenter.dx - labelTp.width / 2,
              labelCenter.dy - labelTp.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PensionRingPainter oldDelegate) {
    return oldDelegate.completeness != completeness ||
        oldDelegate.progress != progress ||
        oldDelegate.contributedYears != contributedYears ||
        oldDelegate.totalYears != totalYears;
  }
}
