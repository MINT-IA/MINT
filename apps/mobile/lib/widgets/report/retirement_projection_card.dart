import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/financial_report.dart';

class RetirementProjectionCard extends StatelessWidget {
  final RetirementProjection projection;
  final int? contributionYears;

  const RetirementProjectionCard({
    super.key,
    required this.projection,
    this.contributionYears,
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
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
            ),
            Text(
              '${replacementRate.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: rateColor),
            ),
            Text(
              ' (cible : 60-80%)',
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textMuted),
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
        // AVS gap warning (if applicable)
        if (gap > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: MintColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$years ann\u00e9es cotis\u00e9es sur 44 requises \u2014 lacune de $gap ans (rente r\u00e9duite de ${(gap / 44 * 100).toStringAsFixed(1)}%)',
                    style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
