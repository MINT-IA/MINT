import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  BUDGET 50/30/20 WIDGET — P5-D / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Budget automatique basé sur le salaire net, le canton et
//  l'âge. 50% fixe, 30% vie, 20% futur.
//
//  Widget pur — aucune dépendance Provider.
//  Lois : L5 (une action) + L1 (CHF/mois)
// ────────────────────────────────────────────────────────────

/// One category of the 50/30/20 budget.
class BudgetCategory {
  final String label;
  final String emoji;
  final double percent;
  final double amount;
  final List<String> examples;

  const BudgetCategory({
    required this.label,
    required this.emoji,
    required this.percent,
    required this.amount,
    required this.examples,
  });
}

class Budget503020Widget extends StatelessWidget {
  final double netSalary;
  final List<BudgetCategory> categories;

  /// Optional highlight: chiffre-choc showing annual savings.
  final String? premierEclairage;

  const Budget503020Widget({
    super.key,
    required this.netSalary,
    required this.categories,
    this.premierEclairage,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Budget 50/30/20. Salaire net\u00a0: '
          '${formatChfWithPrefix(netSalary)}/mois.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ton budget 50 / 30 / 20',
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Basé sur ${formatChfWithPrefix(netSalary)} net/mois',
              style: MintTextStyles.labelMedium(color: MintColors.textMuted),
            ),
            const SizedBox(height: 16),

            // ── Stacked bar ──
            _buildStackedBar(),
            const SizedBox(height: 16),

            // ── Category details ──
            ...categories.map(_buildCategoryCard),

            // ── Chiffre-choc ──
            if (premierEclairage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: MintColors.primary.withValues(alpha: 0.15)),
                ),
                child: Text(
                  premierEclairage!,
                  style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              'R\u00e8gle budg\u00e9taire indicative. '
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedBar() {
    final colors = [
      MintColors.primary,
      MintColors.scoreExcellent,
      MintColors.accent,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            for (var i = 0; i < categories.length && i < 3; i++)
              Expanded(
                flex: categories[i].percent.round(),
                child: Container(
                  color: i < colors.length
                      ? colors[i]
                      : MintColors.textMuted,
                  alignment: Alignment.center,
                  child: Text(
                    '${categories[i].percent.round()}%',
                    style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BudgetCategory cat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${cat.label} (${cat.percent.round()}%)',
                        style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      formatChfWithPrefix(cat.amount),
                      style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  cat.examples.join(' \u00b7 '),
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
