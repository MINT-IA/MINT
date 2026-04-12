import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  DOUBLE PRICE OF FREEDOM WIDGET — P6-C / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Comparaison côte à côte charges salarié vs indépendant.
//  Le prix réel de la liberté.
//
//  Widget pur — aucune dépendance Provider.
//  Lois : L1 (CHF/mois) + L6 (chiffre-choc)
// ────────────────────────────────────────────────────────────

/// Single charge line for comparison.
class ChargeLine {
  final String label;
  final double employeeAmount;
  final double selfEmployedAmount;
  final String? note;

  const ChargeLine({
    required this.label,
    required this.employeeAmount,
    required this.selfEmployedAmount,
    this.note,
  });
}

class DoublePriceFreedomWidget extends StatelessWidget {
  final double grossIncome;
  final List<ChargeLine> charges;
  final double totalEmployee;
  final double totalSelfEmployed;

  const DoublePriceFreedomWidget({
    super.key,
    required this.grossIncome,
    required this.charges,
    required this.totalEmployee,
    required this.totalSelfEmployed,
  });

  double get _multiplier =>
      totalEmployee > 0 ? totalSelfEmployed / totalEmployee : 0;
  double get _monthlyDelta => (totalSelfEmployed - totalEmployee) / 12;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Double prix de la libert\u00e9. '
          'Salari\u00e9\u00a0: ${formatChfWithPrefix(totalEmployee)}/an. '
          'Ind\u00e9pendant\u00a0: ${formatChfWithPrefix(totalSelfEmployed)}/an.',
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
              'Le double prix de ta libert\u00e9',
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Charges totales \u00e0 ${formatChfWithPrefix(grossIncome)} brut/an',
              style: MintTextStyles.labelMedium(color: MintColors.textMuted),
            ),
            const SizedBox(height: 16),

            // ── Column headers ──
            _buildColumnHeaders(),
            const Divider(height: 16),

            // ── Charge lines ──
            ...charges.map(_buildChargeLine),

            const Divider(height: 16),

            // ── Totals ──
            _buildTotalRow(),
            const SizedBox(height: 12),

            // ── Chiffre-choc ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.scoreCritique.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Tu paies ${formatChfWithPrefix(_monthlyDelta.abs())}/mois '
                'de plus (\u00d7${_multiplier.toStringAsFixed(1)}).\n'
                'Pour garder le m\u00eame net, facture '
                '+${((_multiplier - 1) * 100).toStringAsFixed(0)}%.',
                style: MintTextStyles.labelMedium(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w500, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Cotisations sociales\u00a0: LAVS art. 4-14, LAA art. 1a, LACI art. 2. '
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Row(
      children: [
        const Expanded(flex: 3, child: SizedBox()),
        Expanded(
          flex: 2,
          child: Text(
            'Salari\u00e9\u00b7e',
            textAlign: TextAlign.right,
            style: MintTextStyles.labelSmall(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Ind\u00e9p.',
            textAlign: TextAlign.right,
            style: MintTextStyles.labelSmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildChargeLine(ChargeLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              line.label,
              style: MintTextStyles.labelMedium(color: MintColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatChfWithPrefix(line.employeeAmount),
              textAlign: TextAlign.right,
              style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatChfWithPrefix(line.selfEmployedAmount),
              textAlign: TextAlign.right,
              style: MintTextStyles.labelMedium(color: line.selfEmployedAmount > line.employeeAmount ? MintColors.scoreCritique : MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            'TOTAL /an',
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            formatChfWithPrefix(totalEmployee),
            textAlign: TextAlign.right,
            style: MintTextStyles.bodySmall(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            formatChfWithPrefix(totalSelfEmployed),
            textAlign: TextAlign.right,
            style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
