import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  TRAJECTORY COMPARISON CARD — Phase 5 / Dashboard Assembly
// ────────────────────────────────────────────────────────────
//
// Compare la projection initiale (day-1, gris pointillé) avec
// la projection actuelle (couleur primaire).
//
// Affiche le delta en CHF/mois et le sens de tendance.
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class TrajectoryComparisonCard extends StatelessWidget {
  /// Revenu mensuel retraite estimé au jour 1 (scenario base).
  final double initialMonthly;

  /// Revenu mensuel retraite estimé aujourd'hui (scenario base).
  final double currentMonthly;

  /// Capital final estimé au jour 1.
  final double initialCapital;

  /// Capital final estimé aujourd'hui.
  final double currentCapital;

  const TrajectoryComparisonCard({
    super.key,
    required this.initialMonthly,
    required this.currentMonthly,
    required this.initialCapital,
    required this.currentCapital,
  });

  @override
  Widget build(BuildContext context) {
    final deltaMonthly = currentMonthly - initialMonthly;
    final deltaCapital = currentCapital - initialCapital;
    final isPositive = deltaMonthly >= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: MintColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? MintColors.success : MintColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Évolution depuis ton profil initial',
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Monthly comparison bars
            _ComparisonRow(
              label: 'Revenu retraite / mois',
              initial: initialMonthly,
              current: currentMonthly,
              delta: deltaMonthly,
            ),
            const SizedBox(height: 12),
            _ComparisonRow(
              label: 'Capital total projeté',
              initial: initialCapital,
              current: currentCapital,
              delta: deltaCapital,
            ),

            const SizedBox(height: 12),
            Text(
              'Estimation basée sur ton profil actuel vs ton profil initial. '
              'Outil éducatif, ne constitue pas un conseil.',
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.normal),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double initial;
  final double current;
  final double delta;

  const _ComparisonRow({
    required this.label,
    required this.initial,
    required this.current,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final maxVal =
        initial > current ? initial : current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
        ),
        const SizedBox(height: 6),

        // Initial bar (grey, dashed effect via dotted pattern)
        _Bar(
          value: initial,
          maxValue: maxVal,
          color: MintColors.border,
          label: 'Jour 1 : ${formatChf(initial)}',
        ),
        const SizedBox(height: 4),

        // Current bar (primary)
        _Bar(
          value: current,
          maxValue: maxVal,
          color: MintColors.primary,
          label: 'Aujourd\'hui : ${formatChf(current)}',
        ),
        const SizedBox(height: 4),

        // Delta annotation
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? "+" : ""}${formatChf(delta)}',
              style: MintTextStyles.labelSmall(color: isPositive ? MintColors.success : MintColors.error).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color color;
  final String label;

  const _Bar({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w400),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
