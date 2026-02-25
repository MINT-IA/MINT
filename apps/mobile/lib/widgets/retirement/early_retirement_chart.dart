import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Stacked bar chart comparing retirement income at ages 63-70.
///
/// Each bar shows income decomposition by source.
/// Age 65 highlighted as reference.
/// Badge under each bar: penalty/bonus percentage.
/// CHF monthly total above each bar.
/// Annotation: cumulative difference vs age 65.
class EarlyRetirementChart extends StatefulWidget {
  final List<EarlyRetirementScenario> scenarios;

  const EarlyRetirementChart({super.key, required this.scenarios});

  @override
  State<EarlyRetirementChart> createState() => _EarlyRetirementChartState();
}

class _EarlyRetirementChartState extends State<EarlyRetirementChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _tappedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
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
    if (widget.scenarios.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 320,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _EarlyRetirementPainter(
                  scenarios: widget.scenarios,
                  progress: _animation.value,
                  tappedIndex: _tappedIndex,
                ),
                child: GestureDetector(
                  onTapDown: (d) => _handleTap(d, context),
                  onTapUp: (_) => _clearTap(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Cumulative annotation for age 63
        if (widget.scenarios.length >= 3) _buildCumulativeNote(),

        // Tooltip
        if (_tappedIndex != null) _buildTooltip(),
      ],
    );
  }

  void _handleTap(TapDownDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final pos = details.localPosition;
    final count = widget.scenarios.length;
    const chartLeft = 50.0;
    final chartWidth = size.width - 60;
    final spacing = chartWidth / count;

    for (int i = 0; i < count; i++) {
      final barX = chartLeft + spacing * i;
      if (pos.dx >= barX && pos.dx <= barX + spacing) {
        setState(() => _tappedIndex = i);
        return;
      }
    }
  }

  void _clearTap() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _tappedIndex = null);
    });
  }

  Widget _buildCumulativeNote() {
    final earliest = widget.scenarios.first;
    final diff = earliest.cumulativeDifference;
    if (diff.abs() < 100) return const SizedBox.shrink();

    final isNeg = diff < 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isNeg ? MintColors.error : MintColors.success)
            .withValues(alpha: 0.06),
        borderRadius: const BorderRadius.circular(10),
        border: Border.all(
          color: (isNeg ? MintColors.error : MintColors.success)
              .withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isNeg ? Icons.trending_down : Icons.trending_up,
            color: isNeg ? MintColors.error : MintColors.success,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Retraite a ${earliest.retirementAge} ans vs 65 ans : '
              'difference cumulee de ${RetirementProjectionService.formatChf(diff.abs())} '
              'sur l\'esperance de vie. '
              '${isNeg ? "Tu recois moins longtemps mais tu pars plus tot." : "Tu recois plus longtemps."}',
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

  Widget _buildTooltip() {
    final scenario = widget.scenarios[_tappedIndex!];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const BorderRadius.circular(10),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Retraite a ${scenario.retirementAge} ans — '
            '${RetirementProjectionService.formatChf(scenario.totalMonthly)}/mois',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...scenario.sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: const BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      RetirementProjectionService.formatChf(s.monthlyAmount),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _EarlyRetirementPainter extends CustomPainter {
  final List<EarlyRetirementScenario> scenarios;
  final double progress;
  final int? tappedIndex;

  _EarlyRetirementPainter({
    required this.scenarios,
    required this.progress,
    this.tappedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scenarios.isEmpty) return;

    const chartTop = 30.0;
    final chartBottom = size.height - 50;
    final chartHeight = chartBottom - chartTop;
    const chartLeft = 50.0;
    final chartRight = size.width - 10;
    final chartWidth = chartRight - chartLeft;

    // Max value
    double maxVal = 0;
    for (final s in scenarios) {
      maxVal = max(maxVal, s.totalMonthly);
    }
    if (maxVal <= 0) return;
    maxVal *= 1.15;

    // Y-axis
    const ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      final val = maxVal * i / ySteps;
      final y = chartBottom - (chartHeight * i / ySteps);

      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        Paint()
          ..color = MintColors.lightBorder
          ..strokeWidth = 0.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: _formatK(val),
          style: GoogleFonts.inter(fontSize: 10, color: MintColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - 6));
    }

    // Bars
    final count = scenarios.length;
    final spacing = chartWidth / count;
    final barWidth = spacing * 0.55;

    for (int i = 0; i < count; i++) {
      final scenario = scenarios[i];
      final barX = chartLeft + spacing * i + (spacing - barWidth) / 2;
      final isRef = scenario.retirementAge == 65;
      final isTapped = tappedIndex == i;

      // Stagger animation left to right
      final staggerProgress =
          ((progress - i * 0.05).clamp(0.0, 1.0) / (1 - i * 0.05))
              .clamp(0.0, 1.0);

      // Reference highlight border
      if (isRef) {
        final totalH =
            (scenario.totalMonthly / maxVal) * chartHeight * staggerProgress;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX - 2, chartBottom - totalH - 2, barWidth + 4,
                totalH + 4),
            const Radius.circular(8),
          ),
          Paint()
            ..color = MintColors.coachAccent.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // Draw segments
      double currentY = chartBottom;
      for (int j = 0; j < scenario.sources.length; j++) {
        final source = scenario.sources[j];
        final segH =
            (source.monthlyAmount / maxVal) * chartHeight * staggerProgress;
        if (segH < 1) continue;

        final isTop = j == scenario.sources.length - 1;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(barX, currentY - segH, barWidth, segH),
          topLeft: isTop ? const Radius.circular(6) : Radius.zero,
          topRight: isTop ? const Radius.circular(6) : Radius.zero,
        );
        canvas.drawRRect(
          rect,
          Paint()..color = isTapped ? source.color.withValues(alpha: 0.8) : source.color,
        );
        currentY -= segH;
      }

      // Age label
      final ageTP = TextPainter(
        text: TextSpan(
          text: '${scenario.retirementAge}',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: isRef ? FontWeight.w800 : FontWeight.w600,
            color: isRef ? MintColors.coachAccent : MintColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ageTP.paint(
        canvas,
        Offset(barX + barWidth / 2 - ageTP.width / 2, chartBottom + 6),
      );

      // Penalty/bonus badge
      final adjPct = scenario.adjustmentPct;
      if (adjPct.abs() > 0.1) {
        final sign = adjPct > 0 ? '+' : '';
        final badgeTP = TextPainter(
          text: TextSpan(
            text: '$sign${adjPct.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: adjPct < 0 ? MintColors.error : MintColors.success,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        badgeTP.paint(
          canvas,
          Offset(barX + barWidth / 2 - badgeTP.width / 2, chartBottom + 22),
        );
      } else {
        final refTP = TextPainter(
          text: TextSpan(
            text: 'ref.',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: MintColors.coachAccent,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        refTP.paint(
          canvas,
          Offset(barX + barWidth / 2 - refTP.width / 2, chartBottom + 22),
        );
      }

      // Amount on top
      if (staggerProgress > 0.5) {
        final amtTP = TextPainter(
          text: TextSpan(
            text: _formatK(scenario.totalMonthly),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        amtTP.paint(
          canvas,
          Offset(barX + barWidth / 2 - amtTP.width / 2, currentY - 16),
        );
      }
    }
  }

  String _formatK(double value) {
    if (value >= 1000) return "${(value / 1000).toStringAsFixed(1)}k";
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _EarlyRetirementPainter old) =>
      old.progress != progress || old.tappedIndex != tappedIndex;
}
