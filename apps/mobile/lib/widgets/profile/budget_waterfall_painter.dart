import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A single step in the budget waterfall cascade.
class WaterfallStep {
  final String label;
  final double amount;
  final bool isSubtotal;
  final bool isIncome;
  final VoidCallback? onTap;

  const WaterfallStep({
    required this.label,
    required this.amount,
    this.isSubtotal = false,
    this.isIncome = false,
    this.onTap,
  });

  /// Build the full cascade from gross salary to free margin.
  ///
  /// [labels] allows the caller to pass i18n'd labels via S.of(context)!.
  /// If null, French defaults are used.
  static List<WaterfallStep> fromBreakdown({
    required double grossMonthly,
    required double socialCharges,
    required double lppEmployee,
    required double incomeTax,
    required double rent,
    required double healthInsurance,
    double leasing = 0,
    double otherFixed = 0,
    double pillar3a = 0,
    double investment = 0,
    Map<String, String>? labels,
  }) {
    final l = labels ?? const {};
    final netPayslip = grossMonthly - socialCharges - lppEmployee;
    final disposable = netPayslip - incomeTax;
    var resteAVivre = disposable - rent - healthInsurance;
    if (leasing > 0) resteAVivre -= leasing;
    if (otherFixed > 0) resteAVivre -= otherFixed;
    var margeLibre = resteAVivre;
    if (pillar3a > 0) margeLibre -= pillar3a;
    if (investment > 0) margeLibre -= investment;

    final steps = <WaterfallStep>[
      WaterfallStep(label: l['brutMensuel'] ?? 'Brut mensuel', amount: grossMonthly, isIncome: true),
      WaterfallStep(label: l['avsAc'] ?? 'AVS / AC', amount: socialCharges),
      WaterfallStep(label: l['lppEmploye'] ?? 'LPP employ\u00e9', amount: lppEmployee),
      WaterfallStep(label: l['netFicheDePaie'] ?? 'Net fiche de paie', amount: netPayslip, isSubtotal: true),
      WaterfallStep(label: l['impots'] ?? 'Imp\u00f4ts', amount: incomeTax),
      WaterfallStep(label: l['disponible'] ?? 'Disponible', amount: disposable, isSubtotal: true),
      WaterfallStep(label: l['loyer'] ?? 'Loyer', amount: rent),
      WaterfallStep(label: l['lamal'] ?? 'LAMal', amount: healthInsurance),
      if (leasing > 0) WaterfallStep(label: l['leasing'] ?? 'Leasing', amount: leasing),
      if (otherFixed > 0) WaterfallStep(label: l['autresFixes'] ?? 'Autres fixes', amount: otherFixed),
      WaterfallStep(label: l['resteAVivre'] ?? 'Reste \u00e0 vivre', amount: resteAVivre, isSubtotal: true),
      if (pillar3a > 0) WaterfallStep(label: l['pillar3a'] ?? '3a', amount: pillar3a),
      if (investment > 0) WaterfallStep(label: l['investissement'] ?? 'Investissement', amount: investment),
      WaterfallStep(label: l['margeLibre'] ?? 'Marge libre', amount: margeLibre, isSubtotal: true),
    ];

    return steps;
  }
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// A waterfall chart showing the cascade from gross salary to free margin.
///
/// Each horizontal bar is proportional to the first (largest) value.
/// Connector lines link successive bars to illustrate the flow.
class BudgetWaterfallChart extends StatelessWidget {
  final List<WaterfallStep> steps;

  /// Vertical space between rows.
  final double rowSpacing;

  /// Height of each bar.
  final double barHeight;

  const BudgetWaterfallChart({
    super.key,
    required this.steps,
    this.rowSpacing = 6,
    this.barHeight = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final maxAmount = steps.fold<double>(
      0,
      (prev, s) => math.max(prev, s.amount.abs()),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _WaterfallRow(
                step: steps[i],
                maxAmount: maxAmount,
                availableWidth: availableWidth,
                barHeight: barHeight,
                isLast: i == steps.length - 1,
              ),
              if (i < steps.length - 1)
                _ConnectorLine(
                  height: rowSpacing,
                  availableWidth: availableWidth,
                  currentAmount: steps[i].amount.abs(),
                  nextAmount: steps[i + 1].amount.abs(),
                  maxAmount: maxAmount,
                ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single row
// ---------------------------------------------------------------------------

class _WaterfallRow extends StatelessWidget {
  final WaterfallStep step;
  final double maxAmount;
  final double availableWidth;
  final double barHeight;
  final bool isLast;

  const _WaterfallRow({
    required this.step,
    required this.maxAmount,
    required this.availableWidth,
    required this.barHeight,
    required this.isLast,
  });

  /// The portion of width reserved for the bar itself (the rest is labels).
  static const double _barFraction = 0.52;

  @override
  Widget build(BuildContext context) {
    final barAreaWidth = availableWidth * _barFraction;
    final ratio = maxAmount == 0 ? 0.0 : (step.amount.abs() / maxAmount);
    final barWidth = math.max(ratio * barAreaWidth, 4.0);

    final color = _barColor();
    final isHighlighted = isLast && step.isSubtotal;

    final prefix = step.isIncome || step.isSubtotal ? '' : '\u2212\u2009';
    final formattedAmount = '$prefix${formatChf(step.amount.abs())}';

    final row = SizedBox(
      height: barHeight,
      child: Row(
        children: [
          // Label
          SizedBox(
            width: availableWidth * 0.28,
            child: Text(
              step.isSubtotal ? '= ${step.label}' : step.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: step.isSubtotal ? FontWeight.w600 : FontWeight.w400,
                color: step.isSubtotal
                    ? MintColors.textPrimary
                    : MintColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Bar
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: isHighlighted
                  ? _GlowBar(
                      width: barWidth,
                      height: barHeight - 8,
                      color: color,
                    )
                  : Container(
                      width: barWidth,
                      height: barHeight - 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
            ),
          ),

          // Amount
          SizedBox(
            width: availableWidth * 0.20,
            child: Text(
              formattedAmount,
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: step.isSubtotal ? FontWeight.w700 : FontWeight.w500,
                color: step.isSubtotal
                    ? MintColors.textPrimary
                    : MintColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (step.onTap != null) {
      return GestureDetector(
        onTap: step.onTap,
        behavior: HitTestBehavior.opaque,
        child: row,
      );
    }
    return row;
  }

  Color _barColor() {
    if (step.isSubtotal) return MintColors.success;
    if (step.isIncome) return MintColors.primary;
    // Deduction: error at 30% opacity
    return MintColors.error.withValues(alpha: 0.30);
  }
}

// ---------------------------------------------------------------------------
// Glow effect for the final bar (marge libre)
// ---------------------------------------------------------------------------

class _GlowBar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _GlowBar({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connector line between rows
// ---------------------------------------------------------------------------

class _ConnectorLine extends StatelessWidget {
  final double height;
  final double availableWidth;
  final double currentAmount;
  final double nextAmount;
  final double maxAmount;

  const _ConnectorLine({
    required this.height,
    required this.availableWidth,
    required this.currentAmount,
    required this.nextAmount,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: availableWidth,
      height: height,
      child: CustomPaint(
        painter: _ConnectorPainter(
          availableWidth: availableWidth,
          currentAmount: currentAmount,
          nextAmount: nextAmount,
          maxAmount: maxAmount,
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final double availableWidth;
  final double currentAmount;
  final double nextAmount;
  final double maxAmount;

  _ConnectorPainter({
    required this.availableWidth,
    required this.currentAmount,
    required this.nextAmount,
    required this.maxAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxAmount == 0) return;

    final labelWidth = availableWidth * 0.28;
    final barAreaWidth = availableWidth * _WaterfallRow._barFraction;

    final currentBarEnd =
        labelWidth + math.max((currentAmount / maxAmount) * barAreaWidth, 4.0);
    final nextBarEnd =
        labelWidth + math.max((nextAmount / maxAmount) * barAreaWidth, 4.0);

    // Use the smaller of the two bar ends as the x position for the line
    final x = math.min(currentBarEnd, nextBarEnd);

    final paint = Paint()
      ..color = MintColors.border
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return currentAmount != oldDelegate.currentAmount ||
        nextAmount != oldDelegate.nextAmount ||
        maxAmount != oldDelegate.maxAmount;
  }
}
