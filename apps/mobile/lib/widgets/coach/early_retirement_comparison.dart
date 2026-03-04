import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Early retirement comparison mini-table for 45-60 age group.
///
/// Shows replacement rate estimates at ages 63, 64, 65, 67, 70.
/// Only displayed for users aged 45+.
class EarlyRetirementComparison extends StatelessWidget {
  final CoachProfile profile;

  const EarlyRetirementComparison({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.age < 45) return const SizedBox.shrink();

    final projection = RetirementProjectionService.project(profile: profile);
    final preRetirementMonthly = projection.revenuPreRetraiteMensuel;
    if (preRetirementMonthly <= 0) return const SizedBox.shrink();

    const ages = [63, 64, 65, 67, 70];
    final scenarioByAge = <int, EarlyRetirementScenario>{
      for (final s in projection.earlyRetirementComparisons) s.retirementAge: s,
    };
    final rows = <_ComparisonRow>[];

    for (final retAge in ages) {
      if (retAge <= profile.age) continue;
      final scenario = scenarioByAge[retAge];
      if (scenario == null) continue;

      final replacementRate = scenario.totalMonthly / preRetirementMonthly;

      rows.add(_ComparisonRow(
        age: retAge,
        totalMonthly: scenario.totalMonthly,
        replacementRate: replacementRate,
        isTarget: retAge == profile.effectiveRetirementAge,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparaison retraite anticip\u00e9e',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimation du taux de remplacement par \u00e2ge de d\u00e9part',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Header row
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text('Age',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    )),
              ),
              Expanded(
                child: Text('Revenu mensuel',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    )),
              ),
              SizedBox(
                width: 70,
                child: Text('Taux',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    )),
              ),
            ],
          ),
          const Divider(height: 12),
          ...rows.map((r) => _buildRow(r)),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => context.push('/coach/projection'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Simuler ta retraite anticip\u00e9e',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16, color: MintColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Outil \u00e9ducatif \u2014 les taux varient par caisse (LSFin).',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_ComparisonRow r) {
    final bgColor = r.isTarget
        ? MintColors.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    final textWeight = r.isTarget ? FontWeight.w700 : FontWeight.w500;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Row(
              children: [
                Text(
                  '${r.age}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: textWeight,
                    color: MintColors.textPrimary,
                  ),
                ),
                if (r.isTarget)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child:
                        Icon(Icons.star, size: 12, color: MintColors.primary),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              'CHF ${r.totalMonthly.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: textWeight,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${(r.replacementRate * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: textWeight,
                color: r.replacementRate >= 0.60
                    ? MintColors.scoreGreen
                    : r.replacementRate >= 0.45
                        ? MintColors.scoreAttention
                        : MintColors.scoreRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow {
  final int age;
  final double totalMonthly;
  final double replacementRate;
  final bool isTarget;

  const _ComparisonRow({
    required this.age,
    required this.totalMonthly,
    required this.replacementRate,
    required this.isTarget,
  });
}
