import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  PROPERTY SALE WATERFALL CHART
// ────────────────────────────────────────────────────────────
//
//  Waterfall/bridge chart showing property sale proceeds:
//    - Starting bar: "Prix de vente"
//    - Negative steps: hypotheque, impot plus-value, EPL, frais
//    - Positive step: remploi (if applicable)
//    - Ending bar: "Produit net"
//    - Sequential cascade animation
//    - Dashed connecting lines
//    - Net proceeds badge at bottom
// ────────────────────────────────────────────────────────────

/// A single step in the property sale waterfall.
class SaleWaterfallStep {
  final String label;
  final double amount;
  final bool isTotal;

  const SaleWaterfallStep({
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

/// Creates waterfall steps from property sale results.
List<SaleWaterfallStep> buildPropertySaleSteps({
  required double prixVente,
  required double hypothequeRestante,
  required double impotPlusValue,
  required double remboursementEplLpp,
  required double remboursementEpl3a,
  double remploiReport = 0,
  required double produitNet,
}) {
  final steps = <SaleWaterfallStep>[
    SaleWaterfallStep(
      label: 'Prix de\nvente',
      amount: prixVente,
      isTotal: true,
    ),
  ];

  if (hypothequeRestante > 0) {
    steps.add(SaleWaterfallStep(
      label: 'Hypotheque',
      amount: -hypothequeRestante,
    ));
  }

  if (impotPlusValue > 0) {
    steps.add(SaleWaterfallStep(
      label: 'Impot\nplus-value',
      amount: -impotPlusValue,
    ));
  }

  if (remboursementEplLpp > 0) {
    steps.add(SaleWaterfallStep(
      label: 'EPL LPP',
      amount: -remboursementEplLpp,
    ));
  }

  if (remboursementEpl3a > 0) {
    steps.add(SaleWaterfallStep(
      label: 'EPL 3a',
      amount: -remboursementEpl3a,
    ));
  }

  if (remploiReport > 0) {
    steps.add(SaleWaterfallStep(
      label: 'Report\nremploi',
      amount: remploiReport,
    ));
  }

  steps.add(SaleWaterfallStep(
    label: 'Produit\nnet',
    amount: produitNet,
    isTotal: true,
  ));

  return steps;
}

class PropertySaleWaterfall extends StatefulWidget {
  final List<SaleWaterfallStep> steps;
  final double produitNet;
  final int dureeDetention;

  const PropertySaleWaterfall({
    super.key,
    required this.steps,
    required this.produitNet,
    required this.dureeDetention,
  });

  @override
  State<PropertySaleWaterfall> createState() => _PropertySaleWaterfallState();
}

class _PropertySaleWaterfallState extends State<PropertySaleWaterfall>
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
  void didUpdateWidget(PropertySaleWaterfall oldWidget) {
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
          'Graphique en cascade de la vente immobiliere. Produit net: ${_formatChf(widget.produitNet)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
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
                _buildHeader(),
                _buildWaterfallChart(constraints.maxWidth),
                _buildNetProceedsBadge(),
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
              color: MintColors.primary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.real_estate_agent,
              color: MintColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decomposition de la vente',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  'Detention : ${widget.dureeDetention} ans',
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

    return AnimatedBuilder(
      animation: _cascadeAnimation,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 260,
            child: CustomPaint(
              painter: _SaleWaterfallPainter(
                steps: widget.steps,
                runningTotals: totals,
                progress: _cascadeAnimation.value,
              ),
              size: Size(availableWidth - 32, 260),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetProceedsBadge() {
    final isPositive = widget.produitNet >= 0;
    final badgeColor = isPositive ? MintColors.success : MintColors.error;

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
                    badgeColor.withValues(alpha: 0.12),
                    badgeColor.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: const BorderRadius.circular(16),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPositive
                        ? Icons.account_balance_wallet
                        : Icons.warning_amber_rounded,
                    color: badgeColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(
                        'Produit net',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatChf(widget.produitNet),
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ],
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
//  WATERFALL CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _SaleWaterfallPainter extends CustomPainter {
  final List<SaleWaterfallStep> steps;
  final List<double> runningTotals;
  final double progress;

  _SaleWaterfallPainter({
    required this.steps,
    required this.runningTotals,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;

    final barWidth = (size.width / steps.length) * 0.55;
    final spacing = size.width / steps.length;
    final chartHeight = size.height - 60;
    const chartTop = 10.0;
    final chartBottom = chartTop + chartHeight;

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
        barColor = MintColors.warning;
        final prevTotal = i > 0 ? runningTotals[i - 1] : 0.0;
        barTop = yForValue(prevTotal);
        barBottom = yForValue(prevTotal + step.amount);
        if (barTop > barBottom) {
          final tmp = barTop;
          barTop = barBottom;
          barBottom = tmp;
        }
      } else {
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

      final animatedBarHeight = (barBottom - barTop) * stepProgress;
      final animatedBarTop = barBottom - animatedBarHeight;

      final barPaint = Paint()..color = barColor.withValues(alpha: 0.85);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, animatedBarTop, barWidth, animatedBarHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, barPaint);

      // Dashed connector
      if (i < steps.length - 1 && stepProgress >= 1.0) {
        final nextX = spacing * (i + 1) + (spacing - barWidth) / 2;
        final connectorY =
            step.isTotal ? yForValue(step.amount) : yForValue(runningTotals[i]);
        final dashPaint = Paint()
          ..color = MintColors.border
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

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

      // Amount label
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

      // Step label
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
  bool shouldRepaint(covariant _SaleWaterfallPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.steps != steps;
  }
}
