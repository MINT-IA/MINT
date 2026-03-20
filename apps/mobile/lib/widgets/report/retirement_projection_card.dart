import 'package:flutter/material.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class RetirementProjectionCard extends StatelessWidget {
  final RetirementProjection projection;
  final int? contributionYears;
  final String? avsLacunesStatus; // 'no_gaps', 'arrived_late', 'lived_abroad', 'unknown'

  const RetirementProjectionCard({
    super.key,
    required this.projection,
    this.contributionYears,
    this.avsLacunesStatus,
  });

  @override
  Widget build(BuildContext context) {
    final totalMonthly = projection.totalMonthlyIncome;
    final replacementRate = projection.replacementRate;
    final rateColor = replacementRate >= 60
        ? MintColors.success
        : replacementRate >= 40
            ? MintColors.warning
            : MintColors.error;

    final years = contributionYears ?? (projection.avsReductionFactor * 44).floor();
    final gap = 44 - years;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breakdown
        _infoRow('Rente AVS mensuelle', 'CHF ${projection.monthlyAvsRent.toStringAsFixed(0)}'),
        const SizedBox(height: 6),
        _infoRow('Rente LPP mensuelle', 'CHF ${projection.monthlyLppRent.toStringAsFixed(0)}'),
        const Divider(height: 20),
        _infoRow('TOTAL mensuel estim\u00e9', 'CHF ${totalMonthly.toStringAsFixed(0)}', isBold: true),
        const SizedBox(height: 12),
        // Replacement rate
        Row(
          children: [
            Text(
              'Taux de remplacement : ',
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
            ),
            Text(
              '${replacementRate.toStringAsFixed(0)}%',
              style: MintTextStyles.bodySmall(color: rateColor).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Text(
              ' (cible : 60-80%)',
              style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Replacement rate bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (replacementRate / 100).clamp(0.0, 1.0),
            backgroundColor: MintColors.lightBorder,
            valueColor: AlwaysStoppedAnimation(rateColor),
            minHeight: 6,
          ),
        ),
        // AVS gap warning with actionable advice
        if (gap > 0) ...[
          const SizedBox(height: 16),
          _buildAvsGapWarning(years, gap),
        ],
        // "Unknown" status: user doesn't know about gaps → recommend IK extract
        if (gap <= 0 && avsLacunesStatus == 'unknown') ...[
          const SizedBox(height: 16),
          _buildAvsUnknownTip(),
        ],
      ],
    );
  }

  Widget _buildAvsGapWarning(int years, int gap) {
    final reductionPct = AvsCalculator.reductionPercentageFromGap(gap).toStringAsFixed(1);
    final monthlyLoss = AvsCalculator.monthlyLossFromGap(gap).toStringAsFixed(0);

    final tips = <String>[
      '$years ans cotisés sur 44 requis \u2014 rente réduite de $reductionPct% (\u2212CHF $monthlyLoss/mois)',
    ];
    if (gap <= 5) {
      tips.add('Rachat possible pour les années récentes auprès de ta caisse AVS cantonale (LAVS art. 16)');
    }
    tips.add('Tes cotisations de jeunesse (18-20 ans) comblent automatiquement jusqu\'\u00e0 3 ans de lacune (RAVS art. 52b)');
    tips.add('Commande ton extrait de compte individuel (CI) gratuit sur inforegister.ch pour confirmer');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tips.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                tip == tips.first ? Icons.warning_amber_rounded : Icons.lightbulb_outline,
                size: 14,
                color: tip == tips.first ? MintColors.warning : MintColors.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontSize: 12, height: 1.4, fontWeight: tip == tips.first ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildAvsUnknownTip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 14, color: MintColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Commande ton extrait de compte individuel (CI) gratuit sur inforegister.ch pour v\u00e9rifier tes lacunes AVS. '
              'Chaque ann\u00e9e manquante = \u22122.3% de rente \u00e0 vie.',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: MintTextStyles.bodySmall(color: isBold ? MintColors.textPrimary : MintColors.textSecondary).copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w400),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }
}
