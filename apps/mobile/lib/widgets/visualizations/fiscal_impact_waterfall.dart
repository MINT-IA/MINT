import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  FISCAL IMPACT WATERFALL CHART
// ────────────────────────────────────────────────────────────
//
//  Waterfall/bridge chart showing child tax deduction impact:
//    - Starting bar: "Revenu brut"
//    - Negative steps: deductions (orange)
//    - Positive steps: allocations (green)
//    - Ending bar: "Impact net"
//    - Sequential cascade animation
//    - Dashed connecting lines
//    - Savings badge at bottom
// ────────────────────────────────────────────────────────────

/// A single step in the waterfall chart.
class WaterfallStep {
  final String label;
  final double amount;
  final bool isTotal;

  const WaterfallStep({
    required this.label,
    required this.amount,
    this.isTotal = false,
  });
}

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

class FiscalImpactWaterfall extends StatefulWidget {
  /// Ordered list of waterfall steps.
  /// The first step should be the starting total (isTotal: true).
  /// Intermediate steps are additions or deductions.
  /// The last step should be the ending total (isTotal: true).
  final List<WaterfallStep> steps;

  /// Total savings to display in the badge.
  final double totalSavings;

  const FiscalImpactWaterfall({
    super.key,
    required this.steps,
    required this.totalSavings,
  });

  @override
  State<FiscalImpactWaterfall> createState() => _FiscalImpactWaterfallState();
}

class _FiscalImpactWaterfallState extends State<FiscalImpactWaterfall>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _cascadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 800 + widget.steps.length * 200,
      ),
    );
    _cascadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(FiscalImpactWaterfall oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calculate the running total at each step for positioning.
  List<double> get _runningTotals {
    if (widget.steps.isEmpty) return [];
    final totals = <double>[];
    var running = 0.0;
    for (final step in widget.steps) {
      if (step.isTotal) {
        running = step.amount;
      } else {
        running += step.amount;
      }
      totals.add(running);
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Graphique en cascade de l\'impact fiscal. Economies totales: ${_formatChf(widget.totalSavings)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            decoration: BoxDecoration(
              color: Colors.white,
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
                _buildWaterfallChart(constraints.maxWidth),
                _buildSavingsBadge(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.waterfall_chart,
              color: MintColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact fiscal enfant',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  'Deductions et allocations',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterfallChart(double availableWidth) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final totals = _runningTotals;
    final allValues = <double>[...totals];
    // Also include starting amounts for total bars
    for (final step in widget.steps) {
      allValues.add(step.amount.abs());
    }
    final maxVal =
        allValues.isEmpty ? 1.0 : allValues.map((v) => v.abs()).reduce(max);

    return AnimatedBuilder(
      animation: _cascadeAnimation,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 260,
            child: CustomPaint(
              painter: _WaterfallPainter(
                steps: widget.steps,
                runningTotals: totals,
                maxValue: maxVal,
                progress: _cascadeAnimation.value,
              ),
              size: Size(availableWidth - 32, 260),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavingsBadge() {
    return AnimatedBuilder(
      animation: _cascadeAnimation,
      builder: (context, _) {
        final showBadge = _cascadeAnimation.value > 0.8;
        return AnimatedOpacity(
          opacity: showBadge ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedScale(
            scale: showBadge ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MintColors.success.withValues(alpha: 0.12),
                    MintColors.success.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MintColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decorative dots (confetti-like)
                  _buildConfettiDots(),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(
                        'Economies totales',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatChf(widget.totalSavings),
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MintColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  _buildConfettiDots(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfettiDots() {
    return SizedBox(
      width: 24,
      height: 40,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 4,
            child: _dot(MintColors.success, 5),
          ),
          Positioned(
            left: 14,
            top: 0,
            child: _dot(MintColors.warning, 4),
          ),
          Positioned(
            left: 8,
            top: 14,
            child: _dot(MintColors.info, 3),
          ),
          Positioned(
            left: 0,
            top: 26,
            child: _dot(MintColors.success, 4),
          ),
          Positioned(
            left: 16,
            top: 30,
            child: _dot(MintColors.warning, 3),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  WATERFALL CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _WaterfallPainter extends CustomPainter {
  final List<WaterfallStep> steps;
  final List<double> runningTotals;
  final double maxValue;
  final double progress;

  _WaterfallPainter({
    required this.steps,
    required this.runningTotals,
    required this.maxValue,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;

    final barWidth = (size.width / steps.length) * 0.55;
    final spacing = size.width / steps.length;
    final chartHeight = size.height - 60; // Leave room for labels
    const chartTop = 10.0;
    final chartBottom = chartTop + chartHeight;

    // Compute the base line (0 level)
    // We need to fit all running totals plus the step amounts
    var minVal = 0.0;
    var maxVal = 0.0;
    for (var i = 0; i < steps.length; i++) {
      final total = runningTotals[i];
      if (steps[i].isTotal) {
        maxVal = max(maxVal, total);
        minVal = min(minVal, 0);
      } else {
        final prevTotal = i > 0 ? runningTotals[i - 1] : 0.0;
        maxVal = max(maxVal, max(total, prevTotal));
        minVal = min(minVal, min(total, prevTotal));
      }
    }
    final range = maxVal - minVal;
    if (range == 0) return;

    double yForValue(double val) {
      return chartBottom - ((val - minVal) / range) * chartHeight;
    }

    for (var i = 0; i < steps.length; i++) {
      // Cascade: each bar appears sequentially
      final stepProgress =
          ((progress * steps.length) - i).clamp(0.0, 1.0);
      if (stepProgress <= 0) continue;

      final step = steps[i];
      final x = spacing * i + (spacing - barWidth) / 2;
      final centerX = spacing * i + spacing / 2;

      Color barColor;
      double barTop;
      double barBottom;

      if (step.isTotal) {
        barColor = MintColors.primary;
        barTop = yForValue(step.amount);
        barBottom = yForValue(0);
      } else if (step.amount < 0) {
        // Deduction (negative) — orange
        barColor = MintColors.warning;
        final prevTotal = i > 0 ? runningTotals[i - 1] : 0.0;
        barTop = yForValue(prevTotal);
        barBottom = yForValue(prevTotal + step.amount);
        // Swap so barTop < barBottom (top is less in Y)
        if (barTop > barBottom) {
          final tmp = barTop;
          barTop = barBottom;
          barBottom = tmp;
        }
      } else {
        // Addition (positive) — green
        barColor = MintColors.success;
        final prevTotal = i > 0 ? runningTotals[i - 1] : 0.0;
        barTop = yForValue(prevTotal + step.amount);
        barBottom = yForValue(prevTotal);
        if (barTop > barBottom) {
          final tmp = barTop;
          barTop = barBottom;
          barBottom = tmp;
        }
      }

      // Animate bar height
      final animatedBarHeight = (barBottom - barTop) * stepProgress;
      final animatedBarTop = barBottom - animatedBarHeight;

      // Draw bar
      final barPaint = Paint()..color = barColor.withValues(alpha: 0.85);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, animatedBarTop, barWidth, animatedBarHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, barPaint);

      // Draw dashed connector line to next bar
      if (i < steps.length - 1 && stepProgress >= 1.0) {
        final nextX = spacing * (i + 1) + (spacing - barWidth) / 2;
        final connectorY =
            step.isTotal ? yForValue(step.amount) : yForValue(runningTotals[i]);
        final dashPaint = Paint()
          ..color = MintColors.border
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        // Draw dashed line
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        var startX = x + barWidth;
        while (startX < nextX) {
          canvas.drawLine(
            Offset(startX, connectorY),
            Offset(min(startX + dashWidth, nextX), connectorY),
            dashPaint,
          );
          startX += dashWidth + dashSpace;
        }
      }

      // Draw amount label above/below bar
      final amountText = step.isTotal
          ? _formatChfShort(step.amount)
          : '${step.amount < 0 ? '' : '+'}${_formatChfShort(step.amount)}';
      final amountPainter = TextPainter(
        text: TextSpan(
          text: amountText,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: barColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      amountPainter.layout();
      final labelY = step.amount < 0 && !step.isTotal
          ? barBottom + 2
          : animatedBarTop - amountPainter.height - 2;
      amountPainter.paint(
        canvas,
        Offset(centerX - amountPainter.width / 2, labelY),
      );

      // Draw step label at bottom
      final labelPainter = TextPainter(
        text: TextSpan(
          text: step.label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: MintColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        textAlign: TextAlign.center,
      );
      labelPainter.layout(maxWidth: spacing - 4);
      labelPainter.paint(
        canvas,
        Offset(centerX - labelPainter.width / 2, chartBottom + 6),
      );
    }
  }

  String _formatChfShort(double value) {
    final abs = value.abs().round();
    if (abs >= 1000) {
      final k = abs / 1000;
      return '${value < 0 ? '-' : ''}${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return '${value < 0 ? '-' : ''}$abs';
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.steps != steps;
  }
}
