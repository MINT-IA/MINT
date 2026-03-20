import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  SOCIAL CHARGES COMPARISON — Expatriation & Frontaliers
// ────────────────────────────────────────────────────────────
//
//  Side-by-side animated horizontal bar chart comparing social
//  charges between Switzerland and another country:
//    - Mirror layout: Switzerland (left) vs other country (right)
//    - Rows: AVS/Retraite, Chomage, Maladie, Invalidite, Total
//    - Bars grow from center outward
//    - Percentage labels on each bar
//    - Net difference savings badge
//    - Stagger animation: each row appears 100ms after previous
//    - CustomPainter for the mirrored bars
// ────────────────────────────────────────────────────────────

/// A single charge category row.
class SocialChargeRow {
  final String label;
  final double swissRate; // percentage, e.g. 5.3
  final double otherRate; // percentage

  const SocialChargeRow({
    required this.label,
    required this.swissRate,
    required this.otherRate,
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

class SocialChargesComparison extends StatefulWidget {
  /// List of charge categories to compare.
  final List<SocialChargeRow> charges;

  /// Name of the comparison country.
  final String otherCountryName;

  /// Gross annual salary for CHF impact computation.
  final double grossSalary;

  /// Optional callback on tap.
  final VoidCallback? onTap;

  const SocialChargesComparison({
    super.key,
    required this.charges,
    this.otherCountryName = 'France',
    this.grossSalary = 80000,
    this.onTap,
  });

  @override
  State<SocialChargesComparison> createState() =>
      _SocialChargesComparisonState();
}

class _SocialChargesComparisonState extends State<SocialChargesComparison>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _staggerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 800 + widget.charges.length * 100,
      ),
    );
    _staggerAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(SocialChargesComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.charges != widget.charges ||
        oldWidget.otherCountryName != widget.otherCountryName ||
        oldWidget.grossSalary != widget.grossSalary) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _totalSwiss =>
      widget.charges.fold(0.0, (s, c) => s + c.swissRate);
  double get _totalOther =>
      widget.charges.fold(0.0, (s, c) => s + c.otherRate);
  double get _maxRate => widget.charges
      .expand((c) => [c.swissRate, c.otherRate])
      .fold(0.0, max);

  double get _netDifferenceCHF =>
      (_totalOther - _totalSwiss) / 100 * widget.grossSalary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Comparaison des charges sociales entre la Suisse et ${widget.otherCountryName}. '
          'Total Suisse: ${_totalSwiss.toStringAsFixed(1)}%, '
          '${widget.otherCountryName}: ${_totalOther.toStringAsFixed(1)}%',
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 8),
                  _buildColumnHeaders(),
                  const SizedBox(height: 8),
                  _buildMirrorChart(constraints.maxWidth - 40),
                  const SizedBox(height: 12),
                  _buildTotalRow(),
                  const SizedBox(height: 12),
                  _buildDifferenceBadge(),
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
            color: MintColors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.compare_arrows,
            color: MintColors.info,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Charges sociales comparées',
                style: MintTextStyles.titleMedium(),
              ),
              Text(
                'Suisse vs ${widget.otherCountryName}',
                style: MintTextStyles.bodyMedium().copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeaders() {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Suisse',
                    style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 60), // label column width
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.warning,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.otherCountryName,
                    style: MintTextStyles.labelSmall(color: MintColors.warning).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMirrorChart(double availableWidth) {
    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final totalCount = widget.charges.length;
        const rowHeight = 44.0;
        final chartHeight = totalCount * rowHeight;

        return SizedBox(
          width: availableWidth,
          height: chartHeight,
          child: CustomPaint(
            painter: _MirrorBarPainter(
              charges: widget.charges,
              maxRate: _maxRate > 0 ? _maxRate : 1,
              progress: _staggerAnimation.value,
              rowHeight: rowHeight,
            ),
            size: Size(availableWidth, chartHeight),
          ),
        );
      },
    );
  }

  Widget _buildTotalRow() {
    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final show = _staggerAnimation.value > 0.7;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Row(
              children: [
                Text(
                  '${_totalSwiss.toStringAsFixed(1)}%',
                  style: MintTextStyles.titleMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  'TOTAL',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_totalOther.toStringAsFixed(1)}%',
                  style: MintTextStyles.titleMedium(color: MintColors.warning).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDifferenceBadge() {
    final isSaving = _netDifferenceCHF > 0;
    final color = isSaving ? MintColors.success : MintColors.error;

    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final show = _staggerAnimation.value > 0.85;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedScale(
            scale: show ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSaving
                        ? Icons.savings_outlined
                        : Icons.trending_up,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSaving
                            ? 'Économie en Suisse'
                            : 'Surcoût en Suisse',
                        style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${isSaving ? '+' : ''}${_formatChf(_netDifferenceCHF.abs())}/an',
                        style: MintTextStyles.titleMedium(color: color).copyWith(fontWeight: FontWeight.w800),
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
//  MIRROR BAR CUSTOM PAINTER
// ────────────────────────────────────────────────────────────

class _MirrorBarPainter extends CustomPainter {
  final List<SocialChargeRow> charges;
  final double maxRate;
  final double progress;
  final double rowHeight;

  _MirrorBarPainter({
    required this.charges,
    required this.maxRate,
    required this.progress,
    required this.rowHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final halfBarWidth = (size.width - 80) / 2; // 80 for center label area
    const barHeight = 18.0;
    const barRadius = Radius.circular(4);

    for (var i = 0; i < charges.length; i++) {
      // Stagger: each row appears 1/totalCount later
      final rowProgress =
          ((progress * (charges.length + 1)) - i).clamp(0.0, 1.0);
      if (rowProgress <= 0) continue;

      final charge = charges[i];
      final y = i * rowHeight + (rowHeight - barHeight) / 2;

      // Swiss bar (grows left from center)
      final swissWidth =
          (charge.swissRate / maxRate) * halfBarWidth * rowProgress;
      final swissPaint = Paint()
        ..color = MintColors.primary.withValues(alpha: 0.75);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
              centerX - 30 - swissWidth, y, swissWidth, barHeight),
          topLeft: barRadius,
          bottomLeft: barRadius,
        ),
        swissPaint,
      );

      // Swiss percentage label
      if (rowProgress > 0.5) {
        final swissTp = TextPainter(
          text: TextSpan(
            text: '${charge.swissRate.toStringAsFixed(1)}%',
            style: MintTextStyles.micro(color: MintColors.primary).copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        swissTp.layout();
        swissTp.paint(
          canvas,
          Offset(
            centerX - 30 - swissWidth - swissTp.width - 4,
            y + (barHeight - swissTp.height) / 2,
          ),
        );
      }

      // Other country bar (grows right from center)
      final otherWidth =
          (charge.otherRate / maxRate) * halfBarWidth * rowProgress;
      final otherPaint = Paint()
        ..color = MintColors.warning.withValues(alpha: 0.75);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(centerX + 30, y, otherWidth, barHeight),
          topRight: barRadius,
          bottomRight: barRadius,
        ),
        otherPaint,
      );

      // Other percentage label
      if (rowProgress > 0.5) {
        final otherTp = TextPainter(
          text: TextSpan(
            text: '${charge.otherRate.toStringAsFixed(1)}%',
            style: MintTextStyles.micro(color: MintColors.warning).copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        otherTp.layout();
        otherTp.paint(
          canvas,
          Offset(
            centerX + 30 + otherWidth + 4,
            y + (barHeight - otherTp.height) / 2,
          ),
        );
      }

      // Center label
      final labelTp = TextPainter(
        text: TextSpan(
          text: charge.label,
          style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      labelTp.layout(maxWidth: 56);
      labelTp.paint(
        canvas,
        Offset(
          centerX - labelTp.width / 2,
          y + (barHeight - labelTp.height) / 2,
        ),
      );

      // Separator line
      if (i < charges.length - 1) {
        final linePaint = Paint()
          ..color = MintColors.lightBorder
          ..strokeWidth = 0.5;
        canvas.drawLine(
          Offset(centerX - halfBarWidth - 20, (i + 1) * rowHeight),
          Offset(centerX + halfBarWidth + 20, (i + 1) * rowHeight),
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MirrorBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.charges != charges ||
        oldDelegate.maxRate != maxRate;
  }
}
