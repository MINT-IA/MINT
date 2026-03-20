import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/retirement_service.dart';

// ────────────────────────────────────────────────────────────
//  BUDGET GAUGE WIDGET — Sprint S21 + Sprint 2 UX Upgrade
// ────────────────────────────────────────────────────────────
//
// Animated circular gauge showing taux de remplacement:
//   Green zone:  60-80%+
//   Orange zone: 40-60%
//   Red zone:    <40%
//   Center: animated percentage number
//
// Upgrade (Sprint 2):
//   - StatefulWidget with animation (1400ms easeOutCubic)
//   - SweepGradient on the value arc
//   - Glow at arc endpoint (RadialGradient) + bright tip dot
//   - Tick marks at 0%, 40%, 60%, 80%, 100%
//   - Animated center percentage text
//   - Animated comparison bars
//   - Pulse glow on deficit zone
//   - didUpdateWidget restarts animation
// ────────────────────────────────────────────────────────────

class BudgetGaugeWidget extends StatefulWidget {
  final double revenus;
  final double depenses;
  final double tauxRemplacement;

  const BudgetGaugeWidget({
    super.key,
    required this.revenus,
    required this.depenses,
    required this.tauxRemplacement,
  });

  @override
  State<BudgetGaugeWidget> createState() => _BudgetGaugeWidgetState();
}

class _BudgetGaugeWidgetState extends State<BudgetGaugeWidget>
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
  void didUpdateWidget(BudgetGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tauxRemplacement != widget.tauxRemplacement ||
        oldWidget.revenus != widget.revenus ||
        oldWidget.depenses != widget.depenses) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _gaugeColor {
    if (widget.tauxRemplacement >= 60) return MintColors.success;
    if (widget.tauxRemplacement >= 40) return MintColors.warning;
    return MintColors.error;
  }

  String get _gaugeLabel {
    if (widget.tauxRemplacement >= 80) return 'Excellent';
    if (widget.tauxRemplacement >= 60) return 'Suffisant';
    if (widget.tauxRemplacement >= 40) return 'Insuffisant';
    return 'Critique';
  }

  @override
  Widget build(BuildContext context) {
    final solde = widget.revenus - widget.depenses;
    final isSurplus = solde >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // ── Gauge ──────────────────────────────────────
          SizedBox(
            width: 160,
            height: 160,
            child: AnimatedBuilder(
              animation: _fillAnimation,
              builder: (context, _) {
                final displayPercent =
                    (widget.tauxRemplacement * _fillAnimation.value).round();

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: _GaugePainter(
                        percentage: widget.tauxRemplacement.clamp(0, 120),
                        color: _gaugeColor,
                        progress: _fillAnimation.value,
                      ),
                      size: const Size(160, 160),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$displayPercent%',
                          style: MintTextStyles.displayMedium(color: _gaugeColor).copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _gaugeLabel,
                          style: MintTextStyles.bodySmall(color: _gaugeColor).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Taux de remplacement',
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Objectif : 60-80% du revenu pre-retraite',
            style: MintTextStyles.bodyMedium(color: MintColors.textMuted).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // ── Revenus vs Depenses bars (animated) ──────
          AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              return Column(
                children: [
                  _buildComparisonBar(
                    label: 'Revenus retraite',
                    value: widget.revenus,
                    maxValue: max(widget.revenus, widget.depenses),
                    color: MintColors.success,
                  ),
                  const SizedBox(height: 10),
                  _buildComparisonBar(
                    label: 'Depenses mensuelles',
                    value: widget.depenses,
                    maxValue: max(widget.revenus, widget.depenses),
                    color: MintColors.error,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Solde ──────────────────────────────────────
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSurplus ? 'Excedent mensuel' : 'Deficit mensuel',
                style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              AnimatedBuilder(
                animation: _fillAnimation,
                builder: (context, _) {
                  final displaySolde = solde * _fillAnimation.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulse glow when in deficit
                      if (!isSurplus && _fillAnimation.value > 0.8)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MintColors.error,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    MintColors.error.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      Text(
                        '${isSurplus ? '+' : ''}${RetirementService.formatChf(displaySolde)}',
                        style: MintTextStyles.headlineMedium(color: isSurplus ? MintColors.success : MintColors.error).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final rawRatio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final ratio = rawRatio * _fillAnimation.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 13),
            ),
            Text(
              RetirementService.formatChf(value),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.appleSurface,
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  CUSTOM GAUGE PAINTER — Animated with gradient + glow + ticks
// ────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  final double progress;

  _GaugePainter({
    required this.percentage,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;
    const strokeWidth = 10.0;

    const startAngle = 0.75 * pi;
    const sweepAngle = 1.5 * pi;

    // ── Background arc ──
    final bgPaint = Paint()
      ..color = MintColors.appleSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // ── Tick marks at 0%, 40%, 60%, 80%, 100% ──
    _drawTickMarks(canvas, center, radius, strokeWidth);

    // ── Value arc (animated with gradient + glow) ──
    final valueSweep =
        sweepAngle * (percentage / 120).clamp(0.0, 1.0) * progress;

    if (valueSweep > 0.001) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      // SweepGradient fill
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + valueSweep,
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.8),
            color,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(startAngle),
        ).createShader(arcRect);

      canvas.drawArc(arcRect, startAngle, valueSweep, false, fillPaint);

      // ── Glow at endpoint ──
      final endAngle = startAngle + valueSweep;
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
  }

  /// Tick marks at 0%, 40%, 60%, 80%, 100% on the arc
  void _drawTickMarks(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
  ) {
    const startAngle = 0.75 * pi;
    const totalSweep = 1.5 * pi;
    final tickRadius = radius + strokeWidth / 2 + 4;

    // Positions: 0%, 40%, 60%, 80%, 100% map to fractions 0/120, 40/120, 60/120, 80/120, 100/120
    // The gauge goes 0-120 so 100% mark is at 100/120 of the arc
    final tickPositions = [
      {'fraction': 0.0 / 120.0, 'label': '0%'},
      {'fraction': 40.0 / 120.0, 'label': '40%'},
      {'fraction': 60.0 / 120.0, 'label': '60%'},
      {'fraction': 80.0 / 120.0, 'label': '80%'},
      {'fraction': 100.0 / 120.0, 'label': '100%'},
    ];

    for (final tick in tickPositions) {
      final fraction = tick['fraction'] as double;
      final label = tick['label'] as String;
      final angle = startAngle + totalSweep * fraction;

      final innerPoint = Offset(
        center.dx + tickRadius * cos(angle),
        center.dy + tickRadius * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + (tickRadius + 5) * cos(angle),
        center.dy + (tickRadius + 5) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = MintColors.border.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Label
      final labelTp = TextPainter(
        text: TextSpan(
          text: label,
          style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontSize: 8, fontWeight: FontWeight.w500, fontStyle: FontStyle.normal),
        ),
        textDirection: TextDirection.ltr,
      );
      labelTp.layout();
      final labelCenter = Offset(
        center.dx + (tickRadius + 14) * cos(angle),
        center.dy + (tickRadius + 14) * sin(angle),
      );
      labelTp.paint(
        canvas,
        Offset(
          labelCenter.dx - labelTp.width / 2,
          labelCenter.dy - labelTp.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}
