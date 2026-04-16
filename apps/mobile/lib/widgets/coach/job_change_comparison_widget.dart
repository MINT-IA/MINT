import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P11-A  Le Prix du changement — avant/après nouveau job
//  Charte : L2 (Avant/Après) + L6 (Chiffre-choc)
//  Source : CO art. 335, LPP art. 14-16
// ────────────────────────────────────────────────────────────

class JobAxis {
  const JobAxis({
    required this.label,
    required this.emoji,
    required this.currentValue,
    required this.newValue,
    required this.unit,
    this.higherIsBetter = true,
    this.note,
  });

  final String label;
  final String emoji;
  final double currentValue;
  final double newValue;
  final String unit;
  final bool higherIsBetter;
  final String? note;
}

class JobChangeComparisonWidget extends StatelessWidget {
  const JobChangeComparisonWidget({
    super.key,
    required this.currentJobLabel,
    required this.newJobLabel,
    required this.axes,
  });

  final String currentJobLabel;
  final String newJobLabel;
  final List<JobAxis> axes;

  @override
  Widget build(BuildContext context) {
    final netMonthly = axes
        .where((a) => a.unit == 'CHF/mois')
        .fold<double>(0, (s, a) => s + (a.newValue - a.currentValue));

    return Semantics(
      label: 'Prix du changement comparaison emploi avant après',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(netMonthly),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildColumnHeaders(),
                  const SizedBox(height: 10),
                  ...axes.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildAxisRow(a),
                  )),
                  const SizedBox(height: 8),
                  _buildNetCallout(netMonthly),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double netMonthly) {
    final positive = netMonthly >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: positive
            ? MintColors.scoreExcellent.withValues(alpha: 0.1)
            : MintColors.scoreCritique.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💼', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le prix du changement',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currentJobLabel → $newJobLabel',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ],
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
            'Actuel',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Nouveau',
            style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Delta',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildAxisRow(JobAxis a) {
    final delta = a.newValue - a.currentValue;
    final isPositive = a.higherIsBetter ? delta >= 0 : delta <= 0;
    final color = delta == 0
        ? MintColors.textSecondary
        : isPositive
            ? MintColors.scoreExcellent
            : MintColors.scoreCritique;
    final sign = delta > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(a.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.label,
                        style: MintTextStyles.labelMedium(color: MintColors.textPrimary),
                      ),
                      if (a.note != null)
                        Text(
                          a.note!,
                          style: MintTextStyles.labelTiny(color: MintColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${formatChf(a.currentValue)} ${a.unit.replaceAll('CHF/', '')}',
              style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${formatChf(a.newValue)} ${a.unit.replaceAll('CHF/', '')}',
              style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$sign${formatChf(delta)} ${a.unit.replaceAll('CHF/', '')}',
              style: MintTextStyles.labelMedium(color: color).copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetCallout(double netMonthly) {
    final positive = netMonthly >= 0;
    final sign = netMonthly >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (positive ? MintColors.scoreExcellent : MintColors.scoreCritique)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (positive ? MintColors.scoreExcellent : MintColors.scoreCritique)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(positive ? '💰' : '⚠️', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact réel : $sign ${formatChfWithPrefix(netMonthly.abs())}/mois',
                  style: MintTextStyles.titleMedium(color: positive ? MintColors.scoreExcellent : MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  positive
                      ? 'Ton nouveau job est financièrement avantageux — négocie fort !'
                      : 'Pense à négocier pour compenser. Chaque CHF compte sur 20 ans de LPP.',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : CO art. 335, LPP art. 14-16.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
