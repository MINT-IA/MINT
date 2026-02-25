import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  MARRIAGE PENALTY / BONUS THERMOMETER GAUGE
// ────────────────────────────────────────────────────────────
//
//  Vertical thermometer showing the fiscal impact of marriage:
//    Red zone above center = penalty (you pay MORE married)
//    Green zone below center = bonus (you pay LESS married)
//    Animated mercury with glow effect at tip
//    Labels: single tax on left, married tax on right
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

class MarriagePenaltyGauge extends StatefulWidget {
  /// Total tax paid by two single individuals.
  final double taxSingles;

  /// Total tax paid as married couple.
  final double taxMarried;

  /// Optional callback when the gauge is tapped.
  final VoidCallback? onTap;

  const MarriagePenaltyGauge({
    super.key,
    required this.taxSingles,
    required this.taxMarried,
    this.onTap,
  });

  @override
  State<MarriagePenaltyGauge> createState() => _MarriagePenaltyGaugeState();
}

class _MarriagePenaltyGaugeState extends State<MarriagePenaltyGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _mercuryAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _setupAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(MarriagePenaltyGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taxSingles != widget.taxSingles ||
        oldWidget.taxMarried != widget.taxMarried) {
      _setupAnimation();
      _controller.forward(from: 0);
    }
  }

  void _setupAnimation() {
    _mercuryAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Difference: positive = penalty, negative = bonus.
  double get _difference => widget.taxMarried - widget.taxSingles;

  /// Normalized position: -1 (max bonus) to +1 (max penalty), 0 = neutral.
  double get _normalizedPosition {
    if (_difference == 0) return 0;
    final maxRef = max(widget.taxSingles, widget.taxMarried);
    if (maxRef == 0) return 0;
    return (_difference / maxRef).clamp(-1.0, 1.0);
  }

  bool get _isPenalty => _difference > 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Thermometre penalite du mariage. Difference: ${_formatChf(_difference)}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.circular(20),
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
                  // Title
                  Text(
                    'Impact fiscal du mariage',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isPenalty
                        ? 'Penalite du mariage'
                        : _difference < 0
                            ? 'Bonus du mariage'
                            : 'Aucun impact',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isPenalty
                          ? MintColors.error
                          : _difference < 0
                              ? MintColors.success
                              : MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Thermometer + labels row
                  SizedBox(
                    height: 280,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left label: singles
                        Expanded(
                          child: _buildSideLabel(
                            title: '2 celibataires',
                            amount: widget.taxSingles,
                            alignment: CrossAxisAlignment.end,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Thermometer
                        AnimatedBuilder(
                          animation: _mercuryAnimation,
                          builder: (context, _) {
                            return SizedBox(
                              width: 56,
                              height: 280,
                              child: CustomPaint(
                                painter: _ThermometerPainter(
                                  normalizedPosition: _normalizedPosition *
                                      _mercuryAnimation.value,
                                  isPenalty: _isPenalty,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 16),

                        // Right label: married
                        Expanded(
                          child: _buildSideLabel(
                            title: 'Maries',
                            amount: widget.taxMarried,
                            alignment: CrossAxisAlignment.start,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Difference badge
                  AnimatedBuilder(
                    animation: _mercuryAnimation,
                    builder: (context, _) {
                      return AnimatedOpacity(
                        opacity: _mercuryAnimation.value > 0.5 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _isPenalty
                                ? MintColors.error.withValues(alpha: 0.1)
                                : _difference < 0
                                    ? MintColors.success
                                        .withValues(alpha: 0.1)
                                    : MintColors.surface,
                            borderRadius: const BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isPenalty
                                    ? Icons.trending_up
                                    : _difference < 0
                                        ? Icons.trending_down
                                        : Icons.trending_flat,
                                size: 20,
                                color: _isPenalty
                                    ? MintColors.error
                                    : _difference < 0
                                        ? MintColors.success
                                        : MintColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _difference == 0
                                    ? 'Aucune difference'
                                    : '${_isPenalty ? '+' : ''}${_formatChf(_difference)}/an',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _isPenalty
                                      ? MintColors.error
                                      : _difference < 0
                                          ? MintColors.success
                                          : MintColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSideLabel({
    required String title,
    required double amount,
    required CrossAxisAlignment alignment,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: alignment,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatChf(amount),
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'par an',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  THERMOMETER CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _ThermometerPainter extends CustomPainter {
  /// -1.0 (full bonus/green) to +1.0 (full penalty/red). 0 = center.
  final double normalizedPosition;
  final bool isPenalty;

  _ThermometerPainter({
    required this.normalizedPosition,
    required this.isPenalty,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    const tubeWidth = 20.0;
    const bulbRadius = 16.0;
    const topY = 20.0;
    final bottomY = size.height - 20;
    final centerY = (topY + bottomY) / 2;
    final tubeLeft = centerX - tubeWidth / 2;
    final tubeRight = centerX + tubeWidth / 2;

    // ── Background tube ──
    final tubeBgPaint = Paint()
      ..color = MintColors.surface
      ..style = PaintingStyle.fill;

    final tubePath = Path();
    // Top rounded cap
    tubePath.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(tubeLeft, topY, tubeRight, bottomY),
      const Radius.circular(10),
    ));
    canvas.drawPath(tubePath, tubeBgPaint);

    // ── Center line (0 neutral) ──
    final centerLinePaint = Paint()
      ..color = MintColors.border
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(tubeLeft - 8, centerY),
      Offset(tubeRight + 8, centerY),
      centerLinePaint,
    );

    // ── "0" label at center ──
    final zeroPainter = TextPainter(
      text: TextSpan(
        text: '0',
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: MintColors.textMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    zeroPainter.layout();
    zeroPainter.paint(
      canvas,
      Offset(tubeRight + 12, centerY - zeroPainter.height / 2),
    );

    // ── Zone labels ──
    // Penalty (top)
    final penaltyPainter = TextPainter(
      text: TextSpan(
        text: '+',
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: MintColors.error.withValues(alpha: 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    penaltyPainter.layout();
    penaltyPainter.paint(
      canvas,
      Offset(tubeRight + 12, topY + 4),
    );

    // Bonus (bottom)
    final bonusPainter = TextPainter(
      text: TextSpan(
        text: '-',
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: MintColors.success.withValues(alpha: 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    bonusPainter.layout();
    bonusPainter.paint(
      canvas,
      Offset(tubeRight + 12, bottomY - bonusPainter.height - 4),
    );

    // ── Red gradient background (top half) ──
    final redZonePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          MintColors.error.withValues(alpha: 0.15),
          MintColors.error.withValues(alpha: 0.03),
        ],
      ).createShader(Rect.fromLTRB(tubeLeft, topY, tubeRight, centerY));
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(tubeLeft, topY, tubeRight, centerY),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      redZonePaint,
    );

    // ── Green gradient background (bottom half) ──
    final greenZonePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: [
          MintColors.success.withValues(alpha: 0.03),
          MintColors.success.withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromLTRB(tubeLeft, centerY, tubeRight, bottomY));
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(tubeLeft, centerY, tubeRight, bottomY),
        bottomLeft: const Radius.circular(10),
        bottomRight: const Radius.circular(10),
      ),
      greenZonePaint,
    );

    // ── Mercury fill ──
    // normalizedPosition: positive = penalty (mercury goes UP from center)
    // negative = bonus (mercury goes DOWN from center)
    final mercuryColor = isPenalty ? MintColors.error : MintColors.success;
    final halfHeight = (bottomY - topY) / 2;
    // Mercury tip Y: center - (normalizedPosition * halfHeight)
    // penalty (+) -> tip goes up (lower Y), bonus (-) -> tip goes down (higher Y)
    final mercuryTipY = centerY - (normalizedPosition * halfHeight);
    final mercuryTopY = normalizedPosition > 0
        ? mercuryTipY // penalty: top = tip, bottom = center
        : centerY; // bonus: top = center, bottom = tip
    final mercuryBottomY = normalizedPosition > 0 ? centerY : mercuryTipY;

    if ((mercuryBottomY - mercuryTopY).abs() > 1) {
      final mercuryPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            mercuryColor.withValues(alpha: 0.9),
            mercuryColor.withValues(alpha: 0.7),
          ],
        ).createShader(
            Rect.fromLTRB(tubeLeft + 3, mercuryTopY, tubeRight - 3, mercuryBottomY));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(tubeLeft + 3, mercuryTopY, tubeRight - 3, mercuryBottomY),
          const Radius.circular(7),
        ),
        mercuryPaint,
      );

      // ── Glow at mercury tip ──
      final glowY = normalizedPosition > 0 ? mercuryTopY : mercuryBottomY;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            mercuryColor.withValues(alpha: 0.4),
            mercuryColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(centerX, glowY), radius: bulbRadius),
        );
      canvas.drawCircle(Offset(centerX, glowY), bulbRadius, glowPaint);

      // ── Mercury tip bulb ──
      final bulbPaint = Paint()..color = mercuryColor;
      canvas.drawCircle(Offset(centerX, glowY), 7, bulbPaint);
    }

    // ── Tube border ──
    final borderPaint = Paint()
      ..color = MintColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(tubeLeft, topY, tubeRight, bottomY),
        const Radius.circular(10),
      ),
      borderPaint,
    );

    // ── Tick marks on right side ──
    final tickPaint = Paint()
      ..color = MintColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final y = topY + (bottomY - topY) * i / 10;
      if ((y - centerY).abs() > 5) {
        canvas.drawLine(
          Offset(tubeRight, y),
          Offset(tubeRight + 4, y),
          tickPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThermometerPainter oldDelegate) {
    return oldDelegate.normalizedPosition != normalizedPosition ||
        oldDelegate.isPenalty != isPenalty;
  }
}
