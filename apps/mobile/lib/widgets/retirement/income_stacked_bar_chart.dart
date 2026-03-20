import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Stacked bar chart showing retirement income by source.
///
/// If couple with age difference: 2 bars side by side (Phase 1 / Phase 2).
/// If single or same age: 1 bar.
/// Optional reference bar for current income (transparent).
/// Dashed red line for monthly expenses.
/// Animated segments with TweenAnimationBuilder.
/// Tap segment -> tooltip with source details.
class IncomeStackedBarChart extends StatefulWidget {
  final List<RetirementPhase> phases;
  final double? currentIncome;
  final double? monthlyExpenses;

  const IncomeStackedBarChart({
    super.key,
    required this.phases,
    this.currentIncome,
    this.monthlyExpenses,
  });

  @override
  State<IncomeStackedBarChart> createState() => _IncomeStackedBarChartState();
}

class _IncomeStackedBarChartState extends State<IncomeStackedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _tappedPhaseIndex;
  int? _tappedSegmentIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart area
        SizedBox(
          height: 280,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _IncomeBarPainter(
                  phases: widget.phases,
                  currentIncome: widget.currentIncome,
                  monthlyExpenses: widget.monthlyExpenses,
                  progress: _animation.value,
                  tappedPhase: _tappedPhaseIndex,
                  tappedSegment: _tappedSegmentIndex,
                ),
                child: Semantics(
                  label: 'Détail des revenus de retraite',
                  child: GestureDetector(
                    onTapDown: (details) => _handleTap(details, context),
                    onTapUp: (_) => _clearTap(),
                ),
              ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Legend
        _buildLegend(),

        // Tooltip (if tapped)
        if (_tappedPhaseIndex != null && _tappedSegmentIndex != null)
          _buildTooltip(),
      ],
    );
  }

  void _handleTap(TapDownDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final pos = details.localPosition;
    final barCount = widget.phases.length + (widget.currentIncome != null ? 1 : 0);
    final barWidth = (size.width - 60) / barCount * 0.6;
    final spacing = (size.width - 60) / barCount;

    for (int i = 0; i < widget.phases.length; i++) {
      final barX = 40 + spacing * (widget.currentIncome != null ? i + 1 : i) +
          (spacing - barWidth) / 2;
      if (pos.dx >= barX && pos.dx <= barX + barWidth) {
        // Find which segment
        final phase = widget.phases[i];
        final maxVal = _maxValue;
        const chartHeight = 240.0;
        double currentY = chartHeight;

        for (int j = 0; j < phase.sources.length; j++) {
          final segHeight =
              phase.sources[j].monthlyAmount / maxVal * chartHeight *
                  _animation.value;
          final segTop = currentY - segHeight;
          if (pos.dy >= segTop && pos.dy <= currentY) {
            setState(() {
              _tappedPhaseIndex = i;
              _tappedSegmentIndex = j;
            });
            return;
          }
          currentY = segTop;
        }
      }
    }
  }

  void _clearTap() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() { _tappedPhaseIndex = null; _tappedSegmentIndex = null; });
    });
  }

  double get _maxValue {
    double maxVal = 0;
    for (final phase in widget.phases) {
      maxVal = max(maxVal, phase.totalMonthly);
    }
    if (widget.currentIncome != null) maxVal = max(maxVal, widget.currentIncome!);
    return maxVal > 0 ? maxVal * 1.15 : 1;
  }

  Widget _buildLegend() {
    final uniqueSources = <String, Color>{};
    for (final phase in widget.phases) {
      for (final source in phase.sources) {
        uniqueSources.putIfAbsent(source.id.replaceAll(RegExp(r'_(user|conjoint)$'), ''), () => source.color);
      }
    }

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        if (widget.currentIncome != null)
          _legendItem('Revenu actuel', MintColors.textMuted.withValues(alpha: 0.3)),
        ...uniqueSources.entries.map(
          (e) => _legendItem(_legendLabel(e.key), e.value),
        ),
      ],
    );
  }

  String _legendLabel(String id) {
    switch (id) {
      case 'avs': return 'AVS';
      case 'lpp': return 'LPP';
      case '3a': return '3e pilier';
      case 'libre': return 'Patrimoine libre';
      case 'salary': return 'Salaire';
      default: return id;
    }
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTooltip() {
    final phase = widget.phases[_tappedPhaseIndex!];
    final source = phase.sources[_tappedSegmentIndex!];
    final pct = phase.totalMonthly > 0
        ? (source.monthlyAmount / phase.totalMonthly * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: source.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: source.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(
              color: source.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${RetirementProjectionService.formatChf(source.monthlyAmount)}/mois — ${pct.toStringAsFixed(1)}%',
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeBarPainter extends CustomPainter {
  final List<RetirementPhase> phases;
  final double? currentIncome;
  final double? monthlyExpenses;
  final double progress;
  final int? tappedPhase;
  final int? tappedSegment;

  _IncomeBarPainter({
    required this.phases,
    this.currentIncome,
    this.monthlyExpenses,
    required this.progress,
    this.tappedPhase,
    this.tappedSegment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const chartTop = 30.0;
    final chartBottom = size.height - 30;
    final chartHeight = chartBottom - chartTop;
    const chartLeft = 50.0;
    final chartRight = size.width - 10;
    final chartWidth = chartRight - chartLeft;

    // Compute max value
    double maxVal = 0;
    for (final p in phases) {
      maxVal = max(maxVal, p.totalMonthly);
    }
    if (currentIncome != null) maxVal = max(maxVal, currentIncome!);
    if (maxVal <= 0) return;
    maxVal *= 1.15;

    // Y-axis labels
    const ySteps = 4;
    final yLabelPaint = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= ySteps; i++) {
      final val = maxVal * i / ySteps;
      final y = chartBottom - (chartHeight * i / ySteps);

      // Grid line
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        Paint()
          ..color = MintColors.lightBorder
          ..strokeWidth = 0.5,
      );

      // Label
      yLabelPaint.text = TextSpan(
        text: _formatK(val),
        style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontSize: 10, fontStyle: FontStyle.normal),
      );
      yLabelPaint.layout();
      yLabelPaint.paint(canvas, Offset(chartLeft - yLabelPaint.width - 6, y - 6));
    }

    // Bar setup
    final barCount = phases.length + (currentIncome != null ? 1 : 0);
    final spacing = chartWidth / barCount;
    final barWidth = spacing * 0.55;

    // Current income reference bar
    if (currentIncome != null && currentIncome! > 0) {
      final barX = chartLeft + (spacing - barWidth) / 2;
      final barH = (currentIncome! / maxVal) * chartHeight * progress;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, chartBottom - barH, barWidth, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = MintColors.textMuted.withValues(alpha: 0.12),
      );

      // Label
      _drawLabel(canvas, 'Aujourd\'hui', barX + barWidth / 2, chartBottom + 8);
      _drawAmountLabel(canvas, currentIncome!, barX + barWidth / 2, chartBottom - barH - 16);
    }

    // Phase bars
    for (int i = 0; i < phases.length; i++) {
      final phase = phases[i];
      final offset = currentIncome != null ? i + 1 : i;
      final barX = chartLeft + spacing * offset + (spacing - barWidth) / 2;

      double currentY = chartBottom;
      for (int j = 0; j < phase.sources.length; j++) {
        final source = phase.sources[j];
        final segH = (source.monthlyAmount / maxVal) * chartHeight * progress;
        if (segH < 1) continue;

        final isHighlighted = tappedPhase == i && tappedSegment == j;
        final rect = Rect.fromLTWH(barX, currentY - segH, barWidth, segH);
        final rrect = RRect.fromRectAndRadius(
          rect,
          j == phase.sources.length - 1
              ? const Radius.circular(6)
              : Radius.zero,
        );

        final paint = Paint()..color = source.color;
        if (isHighlighted) {
          paint.color = source.color.withValues(alpha: 0.85);
          // Draw highlight border
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = source.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        canvas.drawRRect(rrect, paint);
        currentY -= segH;
      }

      // Phase label
      final label = phases.length > 1 ? 'Phase ${i + 1}' : 'Retraite';
      _drawLabel(canvas, label, barX + barWidth / 2, chartBottom + 8);

      // Total amount on top
      _drawAmountLabel(
        canvas,
        phase.totalMonthly,
        barX + barWidth / 2,
        currentY - 16,
      );
    }

    // Expenses dashed line
    if (monthlyExpenses != null && monthlyExpenses! > 0) {
      final expY = chartBottom - (monthlyExpenses! / maxVal) * chartHeight;
      final dashPaint = Paint()
        ..color = MintColors.error.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;

      double startX = chartLeft;
      while (startX < chartRight) {
        canvas.drawLine(
          Offset(startX, expY),
          Offset(min(startX + 6, chartRight), expY),
          dashPaint,
        );
        startX += 10;
      }

      // Expense label
      final tp = TextPainter(
        text: TextSpan(
          text: 'Depenses ${_formatK(monthlyExpenses!)}',
          style: MintTextStyles.micro(color: MintColors.error.withValues(alpha: 0.8)).copyWith(fontSize: 9, fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartRight - tp.width, expY - 14));
    }
  }

  void _drawLabel(Canvas canvas, String text, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontSize: 10, fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y));
  }

  void _drawAmountLabel(Canvas canvas, double amount, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: _formatK(amount),
        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y));
  }

  String _formatK(double value) {
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}k";
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _IncomeBarPainter old) =>
      old.progress != progress ||
      old.tappedPhase != tappedPhase ||
      old.tappedSegment != tappedSegment;
}
