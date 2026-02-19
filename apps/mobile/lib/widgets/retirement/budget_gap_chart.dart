import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Waterfall / bridge chart showing budget construction at retirement.
///
/// Cascade: AVS → LPP → 3a → Libre → (Total) → Impots → Depenses → Solde
/// Connectors between bars.
/// Replacement rate badge.
/// Sequential bar animation.
class BudgetGapChart extends StatefulWidget {
  final RetirementBudgetGap budgetGap;

  const BudgetGapChart({super.key, required this.budgetGap});

  @override
  State<BudgetGapChart> createState() => _BudgetGapChartState();
}

class _BudgetGapChartState extends State<BudgetGapChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.budgetGap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Replacement rate badge
        _buildReplacementBadge(gap.tauxRemplacement),
        const SizedBox(height: 16),

        // Chart
        SizedBox(
          height: 300,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _WaterfallPainter(
                  gap: gap,
                  progress: _animation.value,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Alerts
        ...gap.alertes.map((a) => _buildAlert(a)),
      ],
    );
  }

  Widget _buildReplacementBadge(double rate) {
    final color = rate >= 80
        ? MintColors.success
        : rate >= 60
            ? MintColors.warning
            : MintColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rate >= 60 ? Icons.check_circle_outline : Icons.warning_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Taux de remplacement : ${rate.toStringAsFixed(0)}%',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  final RetirementBudgetGap gap;
  final double progress;

  _WaterfallPainter({required this.gap, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final chartTop = 20.0;
    final chartBottom = size.height - 50;
    final chartHeight = chartBottom - chartTop;
    final chartLeft = 10.0;
    final chartRight = size.width - 10;
    final chartWidth = chartRight - chartLeft;

    // Build waterfall steps
    final steps = <_WaterfallStep>[
      _WaterfallStep('AVS', gap.avsMensuel, RetirementProjectionService.colorAvs, true),
      _WaterfallStep('LPP', gap.lppMensuel, RetirementProjectionService.colorLpp, true),
      if (gap.troisAMensuel > 0)
        _WaterfallStep('3a', gap.troisAMensuel, RetirementProjectionService.color3a, true),
      if (gap.libreMensuel > 0)
        _WaterfallStep('Libre', gap.libreMensuel, RetirementProjectionService.colorLibre, true),
      _WaterfallStep('Impots', -gap.impotEstimeMensuel, MintColors.textMuted, false),
      _WaterfallStep('Depenses', -gap.depensesMensuelles, MintColors.error, false),
      _WaterfallStep(
        'Solde',
        gap.soldeMensuel,
        gap.soldeMensuel >= 0 ? MintColors.success : MintColors.error,
        false,
        isTotal: true,
      ),
    ];

    // Compute max height needed
    double runningTotal = 0;
    double maxTotal = 0;
    double minTotal = 0;
    for (final step in steps) {
      if (step.isTotal) continue;
      runningTotal += step.value;
      maxTotal = max(maxTotal, runningTotal);
      minTotal = min(minTotal, runningTotal);
    }
    // Include total bar
    maxTotal = max(maxTotal, gap.soldeMensuel.abs());
    final range = max(maxTotal - minTotal, maxTotal);
    if (range <= 0) return;
    final scale = chartHeight / (range * 1.2);
    final zeroY = chartBottom - (-minTotal * scale);

    final barCount = steps.length;
    final spacing = chartWidth / barCount;
    final barWidth = spacing * 0.6;

    double cumulative = 0;

    for (int i = 0; i < barCount; i++) {
      final step = steps[i];
      // Stagger: each bar appears sequentially
      final barDelay = i / barCount * 0.4;
      final barProgress =
          ((progress - barDelay) / (1 - barDelay)).clamp(0.0, 1.0);

      final barX = chartLeft + spacing * i + (spacing - barWidth) / 2;

      double barTop;
      double barBottom;

      if (step.isTotal) {
        // Total bar starts from 0
        if (step.value >= 0) {
          barTop = zeroY - step.value * scale * barProgress;
          barBottom = zeroY;
        } else {
          barTop = zeroY;
          barBottom = zeroY - step.value * scale * barProgress;
        }
      } else if (step.isAdditive) {
        // Additive: stacks up from cumulative
        barTop = zeroY - (cumulative + step.value) * scale * barProgress;
        barBottom = zeroY - cumulative * scale;
      } else {
        // Subtractive: drops down from cumulative
        barTop = zeroY - cumulative * scale;
        barBottom =
            zeroY - (cumulative + step.value) * scale * barProgress;
        // swap if needed
        if (barTop > barBottom) {
          final tmp = barTop;
          barTop = barBottom;
          barBottom = tmp;
        }
      }

      // Draw bar
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(barX, barTop, barX + barWidth, barBottom),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = step.color);

      // Connector line to next bar
      if (i < barCount - 1 && !steps[i + 1].isTotal) {
        final nextX = chartLeft + spacing * (i + 1) + (spacing - barWidth) / 2;
        final connY = step.isAdditive
            ? zeroY - (cumulative + step.value) * scale
            : zeroY - (cumulative + step.value) * scale;

        // Dashed connector
        var startX = barX + barWidth;
        final dashPaint = Paint()
          ..color = MintColors.lightBorder
          ..strokeWidth = 1;
        while (startX < nextX) {
          canvas.drawLine(
            Offset(startX, connY),
            Offset(min(startX + 3, nextX), connY),
            dashPaint,
          );
          startX += 6;
        }
      }

      if (!step.isTotal) {
        cumulative += step.value;
      }

      // Label below
      final labelTP = TextPainter(
        text: TextSpan(
          text: step.label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTP.paint(
        canvas,
        Offset(barX + barWidth / 2 - labelTP.width / 2, chartBottom + 6),
      );

      // Amount above/below bar
      if (barProgress > 0.5) {
        final amtStr = _formatChf(step.value.abs());
        final amtTP = TextPainter(
          text: TextSpan(
            text: amtStr,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: step.color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final amtY = step.value >= 0 || step.isTotal
            ? barTop - amtTP.height - 4
            : barBottom + 4;
        amtTP.paint(
          canvas,
          Offset(barX + barWidth / 2 - amtTP.width / 2, amtY),
        );
      }
    }

    // Zero line
    canvas.drawLine(
      Offset(chartLeft, zeroY),
      Offset(chartRight, zeroY),
      Paint()
        ..color = MintColors.textMuted.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
  }

  String _formatChf(double value) {
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}k";
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter old) =>
      old.progress != progress;
}

class _WaterfallStep {
  final String label;
  final double value;
  final Color color;
  final bool isAdditive;
  final bool isTotal;

  const _WaterfallStep(
    this.label,
    this.value,
    this.color,
    this.isAdditive, {
    this.isTotal = false,
  });
}
