import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  BUDGET SANDWICH CHART — P1-G / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  "Ce qui rentre, ce qui sort, ce qui reste. Point."
//  Remplace le waterfall chart par une metaphore sandwich.
//
//  Widget pur — aucune dependance Provider.
//  Lois : L7 (metaphore bat graphique) + L1 (CHF/mois d'abord)
// ────────────────────────────────────────────────────────────

/// Single income/expense line item.
class BudgetLineItem {
  final String label;
  final double amount;

  const BudgetLineItem({required this.label, required this.amount});
}

class BudgetSandwichChart extends StatelessWidget {
  /// Income sources (AVS, LPP, 3a, etc.)
  final List<BudgetLineItem> incomes;

  /// Expense categories (impots, loyer, LAMal, quotidien, etc.)
  final List<BudgetLineItem> expenses;

  const BudgetSandwichChart({
    super.key,
    required this.incomes,
    required this.expenses,
  });

  double get _totalIncome =>
      incomes.fold(0.0, (sum, item) => sum + item.amount);
  double get _totalExpenses =>
      expenses.fold(0.0, (sum, item) => sum + item.amount);
  double get _margin => _totalIncome - _totalExpenses;

  @override
  Widget build(BuildContext context) {
    final margin = _margin;
    final isPositive = margin >= 0;
    final marginColor =
        isPositive ? MintColors.scoreExcellent : MintColors.scoreCritique;

    return Semantics(
      label: 'Budget retraite. Revenus\u00a0: ${formatChfWithPrefix(_totalIncome)}, '
          'D\u00e9penses\u00a0: ${formatChfWithPrefix(_totalExpenses)}, '
          'Marge\u00a0: ${formatChfWithPrefix(margin)}.',
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
              'Ton budget retraite',
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // ── Ce qui rentre ──
            _buildSection(
              icon: Icons.arrow_downward_rounded,
              label: 'Ce qui rentre',
              total: _totalIncome,
              items: incomes,
              color: MintColors.scoreExcellent,
            ),

            // ── Arrow ──
            _buildArrow('moins'),

            // ── Ce qui sort ──
            _buildSection(
              icon: Icons.arrow_upward_rounded,
              label: 'Ce qui sort',
              total: _totalExpenses,
              items: expenses,
              color: MintColors.scoreCritique,
            ),

            // ── Arrow ──
            _buildArrow('reste'),

            // ── Marge ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: marginColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: marginColor.withValues(alpha: 0.20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color: marginColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: Text(
                        '${isPositive ? "Marge" : "D\u00e9ficit"}\u00a0: ${formatChfWithPrefix(margin.abs())}/mois',
                        style: MintTextStyles.titleMedium(color: marginColor).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPositive
                        ? 'Tu es dans le vert. Ce coussin absorbe les impr\u00e9vus.'
                        : 'Il manque ${formatChfWithPrefix(margin.abs())}/mois. '
                            'Des ajustements sont possibles.',
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // ── Disclaimer ──
            const SizedBox(height: 12),
            Text(
              'Estimations \u00e9ducatives \u2014 ne constitue pas un conseil financier (LSFin).',
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String label,
    required double total,
    required List<BudgetLineItem> items,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                formatChfWithPrefix(total),
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Item breakdown bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: items
                        .where((item) => item.amount > 0)
                        .map((item) {
                      final fraction =
                          total > 0 ? item.amount / total : 0.0;
                      return Container(
                        width: constraints.maxWidth * fraction,
                        color: color.withValues(
                            alpha: (0.3 + 0.7 * fraction).clamp(0.0, 1.0)),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Item labels
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: items.map((item) {
              return Text(
                '${item.label} ${formatChfWithPrefix(item.amount)}',
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.keyboard_arrow_down,
                size: 20, color: MintColors.textMuted),
            Text(
              label,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
